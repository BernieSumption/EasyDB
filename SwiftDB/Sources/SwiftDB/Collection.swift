
/// A collection of Codable objects, backed by an SQLite table
///
/// `Collection` is the main interface to data in SwiftDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Codable>: Filterable {
    let connection: Connection
    let columns: [String]
    let table: String
    let mapper: KeyPathMapper<Row>
    
    private let indices: [Index]
    
    internal init(_ type: Row.Type, _ connection: Connection, _ config: Config?) throws {
        self.connection = connection
        self.mapper = try KeyPathMapper.forType(type)
        self.columns = mapper.rootProperties
        
        let config = config ?? Config()
        self.table = config.tableName ?? defaultTableName(for: Row.self)
        
        var hasIdIndex = false
        var indices = [Index]()
        for indexSpec in config.indices {
            let propertyPath = try mapper.propertyPath(for: indexSpec.keyPath)
            let index = Index(
                [Index.Part(propertyPath, collation: indexSpec.collation)],
                unique: indexSpec.unique)
            indices.append(index)
            if index.parts.map(\.name) == ["id"] {
                hasIdIndex = true
            }
        }
        let hasId = mapper.rootProperties.contains("id")
        if hasId && !hasIdIndex && !config.disableUniqueId {
            let index = Index([Index.Part(["id"], .ascending)], unique: true)
            indices.append(index)
        }
        self.indices = indices
    }
    
    struct Config: Equatable {
        var tableName: String?
        var disableUniqueId = false
        var indices = [CollectionConfig.Index<Row>]()
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: connection)
        try migration.migrateColumns(table: table, columns: columns)
        try migration.migrateIndices(table: table, indices: indices)
    }
    
    public func insert(_ row: Row) throws {
        let statement = try getInsertStatement()
        try StatementEncoder.encode(row, into: statement)
        var _ = try statement.step()
    }
    
    public func insert(_ rows: [Row]) throws {
        try rows.forEach(insert)
    }
    
    private var insertStatement: Statement?
    private func getInsertStatement() throws -> Statement {
        if let statement = insertStatement {
            try statement.reset()
            return statement
        }
        let sql = SQL()
            .insertInto(table, columns: columns)
            .values()
            .bracketed(namedParameters: columns)
            .text
        let statement = try connection.prepare(sql: sql)
        insertStatement = statement
        return statement
    }
    
    public func all() -> QueryBuilder<Row> {
        return QueryBuilder(self)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>, collate: Collation?) -> QueryBuilder<Row> {
        return QueryBuilder(self).filter(sqlFragment, collate: collate)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        return filter(sqlFragment, collate: nil)
    }
}

private func defaultTableName<T>(for type: T.Type) -> String {
    if let custom = type as? CustomTableName.Type {
        return custom.tableName
    }
    return String(describing: type)
}
