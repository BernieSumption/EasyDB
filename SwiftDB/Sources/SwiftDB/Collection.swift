
/// A collection of Codable objects, backed by an SQLite table
///
/// `Collection` is the main interface to data in SwiftDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Codable>: Filterable, DefaultCollations {
    public let tableName: String
    
    let database: Database
    let columns: [String]
    let mapper: KeyPathMapper<Row>
    let defaultCollations: [AnyKeyPath: Collation]
    
    private let indices: [Index]
    
    internal init(_ type: Row.Type, _ database: Database, _ config: CollectionConfig?) throws {
        self.database = database
        self.mapper = try KeyPathMapper.forType(type)
        self.columns = mapper.rootProperties
        
        let config = config ?? .collection(type)
        let propertyConfigs = try config.typedPropertyConfigs(type)
        
        self.tableName = config.tableName ?? defaultTableName(for: Row.self)
        
        var defaultCollations = [AnyKeyPath: Collation]()
        for property in propertyConfigs {
            defaultCollations[property.keyPath.cacheKey] = property.collation
        }
        self.defaultCollations = defaultCollations
        
        var disableDefaultIdIndex = false
        var indices = [Index]()
        var configuredColumns = Set<[String]>()
        for property in propertyConfigs {
            let propertyPath = try mapper.propertyPath(for: property.keyPath)
            if configuredColumns.contains(propertyPath) {
                throw SwiftDBError.misuse(message: "Column \(self.tableName).\(propertyPath.joined(separator: ".")) has been configured more than once")
            }
            configuredColumns.insert(propertyPath)
            for indexSpec in property.indices {
                switch indexSpec.kind {
                case .noDefaultUniqueId:
                    disableDefaultIdIndex = true
                case .index(unique: let unique, collation: let collation):
                    let collation = collation ?? defaultCollations[property.keyPath.cacheKey] ?? .string
                    let index = Index(
                        [Index.Part(propertyPath, collation: collation)],
                        unique: unique)
                    indices.append(index)
                    if index.parts.map(\.path) == [["id"]] {
                        disableDefaultIdIndex = true
                    }
                }
            }
        }
        let hasId = mapper.rootProperties.contains("id")
        if hasId && !disableDefaultIdIndex {
            let index = Index([Index.Part(["id"], collation: .string)], unique: true)
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
        try migration.migrateColumns(table: tableName, columns: columns)
        try migration.migrateIndices(table: tableName, indices: indices)
    }
    
    /// Insert one row into the collection
    ///
    /// - Parameters:
    ///   - row: the row to insert
    ///   - onConflict: What to do when the row violates a uniqueness constraint:
    ///     - `.abort`:  throw an error
    ///     - `.ignore`: make no changes to the existing row
    ///     - `.update`: replace the existing row with the new one
    public func insert(_ row: Row, onConflict: OnConflict? = nil) throws {
        let sql = getInsertSQL(onConflict: onConflict)
        try database.getConnection().execute(sql: sql, namedParameters: row)
    }
    
    /// Insert many rows into the collection, using a transaction so that if any row can not
    /// be inserted due to a uniqueness constraint, no rows will be inserted
    ///
    /// - Parameters:
    ///   - rows: the rows to insert
    ///   - onConflict: What to do when one of the rows violates a uniqueness constraint:
    ///     - `.abort`:  prevent all rows from being inserted and throw an error
    ///     - `.ignore`: allow all non-conflicting rows to be inserted while ignoring conflicting rows
    ///     - `.update`: replace the existing row with the new one
    public func insert(_ rows: [Row], onConflict: OnConflict? = nil) throws {
        guard rows.count > 0 else {
            return
        }
        let sql = getInsertSQL(onConflict: onConflict)
        try database.inAccessQueue {
            // TODO: this spends about 20% of its time compiling the same SQL over and over again
            let connection = try database.getConnection()
            do {
                let statement = try connection.notThreadSafe_prepare(sql: sql)
                try connection.execute(sql: "BEGIN TRANSACTION")
                for row in rows {
                    try statement.clearBoundParameters()
                    try StatementEncoder.encode(row, into: statement)
                    _ = try statement.step()
                    statement.reset()
                }
                try connection.execute(sql: "COMMIT TRANSACTION")
            } catch {
                // don't throw an error if the rollback fails, because we want to see the
                // error that actually caused the statement to fail
                try? connection.execute(sql: "ROLLBACK TRANSACTION")
                throw error
            }
        }
    }
    
    /// Equivalent to `insert(row, onConflict: .replace)`
    public func save(_ row: Row) throws {
        try insert(row, onConflict: .replace)
    }
    
    /// Equivalent to `insert(rows, onConflict: .replace)`
    public func save(_ rows: [Row]) throws {
        try insert(rows, onConflict: .replace)
    }
    
    private func getInsertSQL(onConflict: OnConflict?) -> String {
        return SQL()
            .insertInto(tableName, columns: columns, onConflict: onConflict)
            .values()
            .bracketed(namedParameters: columns)
            .text
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

/// What to do during an insert operation if inserting the entity would violate a uniqueness constraint 
public enum OnConflict {
    /// Throw an error and abort the current transaction
    case abort
    /// Silently ignore rows that can't be inserted
    case ignore
    /// Replace conflicting rows with the new data provided
    case replace
}

protocol DefaultCollations {
    func defaultCollation(for columnKeyPath: AnyKeyPath) -> Collation
}

func defaultTableName<T>(for type: T.Type) -> String {
    if let custom = type as? CustomTableName.Type {
        return custom.tableName
    }
    return String(describing: type)
}
