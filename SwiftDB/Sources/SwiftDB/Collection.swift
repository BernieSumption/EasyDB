
/// A collection of Codable objects, backed by an SQLite table
///
/// `Collection` is the main interface to data in SwiftDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Codable>: Filterable, DefaultCollations {
    let database: Database
    let columns: [String]
    let table: String
    let mapper: KeyPathMapper<Row>
    let defaultCollations: [AnyKeyPath: Collation]
    
    private let indices: [Index]
    
    internal init(_ type: Row.Type, _ database: Database, _ config: CollectionConfig?) throws {
        self.database = database
        self.mapper = try KeyPathMapper.forType(type)
        self.columns = mapper.rootProperties
        
        let config = config ?? .collection(type)
        let propertyConfigs = try config.typedPropertyConfigs(type)
        
        self.table = config.tableName ?? defaultTableName(for: Row.self)
        
        var defaultCollations = [AnyKeyPath: Collation]()
        for property in propertyConfigs {
            defaultCollations[property.keyPath.cacheKey] = property.collation
        }
        self.defaultCollations = defaultCollations
        
        var hasIdIndex = false
        var indices = [Index]()
        var configuredColumns = Set<[String]>()
        for property in propertyConfigs {
            let propertyPath = try mapper.propertyPath(for: property.keyPath)
            if configuredColumns.contains(propertyPath) {
                throw SwiftDBError.misuse(message: "Column \(self.table).\(propertyPath.joined(separator: ".")) has been configured more than once")
            }
            configuredColumns.insert(propertyPath)
            for indexSpec in property.indices {
                let collation = indexSpec.collation ?? defaultCollations[property.keyPath.cacheKey] ?? .string
                let index = Index(
                    [Index.Part(propertyPath, collation: collation)],
                    unique: indexSpec.unique)
                indices.append(index)
                print(index.parts.map(\.name))
                if index.parts.map(\.path) == [["id"]] {
                    hasIdIndex = true
                }
            }
        }
        let hasId = mapper.rootProperties.contains("id")
        if hasId && !hasIdIndex {
            let index = Index([Index.Part(["id"], collation: .string, .ascending)], unique: true)
            indices.append(index)
        }
        self.indices = indices
    }
    
    struct Config: Equatable {
        var tableName: String?
        var indices = [Index]()
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: try database.getConnection())
        try migration.migrateColumns(table: table, columns: columns)
        try migration.migrateIndices(table: table, indices: indices)
    }
    
    public func insert(_ row: Row) throws {
        
        let statement = try getInsertStatement()
        defer { statement.reset() }
        try StatementEncoder.encode(row, into: statement)
        var _ = try statement.step()
    }
    
    public func insert(_ rows: [Row]) throws {
        let connection = try database.getConnection()
        do {
            try database.inAccessQueue {
                try connection.execute(sql: "BEGIN TRANSACTION")
                try rows.forEach(insert)
                try connection.execute(sql: "COMMIT TRANSACTION")
            }
        } catch {
            // don't throw an error if the rollback fails, because we want to see the
            // error that actually caused the statement to fail
            try? connection.execute(sql: "ROLLBACK TRANSACTION")
            throw error
        }
    }
    
    private var insertStatement: Statement?
    private func getInsertStatement() throws -> Statement {
        return try database.inAccessQueue {
            if let statement = insertStatement {
                statement.reset()
                return statement
            }
            let sql = SQL()
                .insertInto(table, columns: columns)
                .values()
                .bracketed(namedParameters: columns)
                .text
            let statement = try database.getConnection().prepare(sql: sql)
            insertStatement = statement
            return statement
        }
    }
    
    public func all() -> QueryBuilder<Row> {
        return QueryBuilder(self)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>, collation: Collation?) -> QueryBuilder<Row> {
        return QueryBuilder(self).filter(sqlFragment, collation: collation)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        return filter(sqlFragment, collation: nil)
    }
    
    func defaultCollation(for columnKeyPath: AnyKeyPath) -> Collation {
        return defaultCollations[columnKeyPath] ?? .string
    }
}

protocol DefaultCollations {
    func defaultCollation(for columnKeyPath: AnyKeyPath) -> Collation
}

private func defaultTableName<T>(for type: T.Type) -> String {
    if let custom = type as? CustomTableName.Type {
        return custom.tableName
    }
    return String(describing: type)
}
