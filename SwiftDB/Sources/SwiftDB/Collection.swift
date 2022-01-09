///
public class Collection<Row: Codable> {
    private let connection: Connection
    private let mapper: KeyPathMapper<Row>
    private let columns: [String]
    private let table: String
    
    
    internal init(_ type: Row.Type, _ connection: Connection) throws {
        self.connection = connection
        self.mapper = try KeyPathMapper(type)
        // TODO: Options API to customise table names
        self.table = String(describing: Row.self)
        self.columns = mapper.rootProperties
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: connection)
        try migration.ensureTableExists(table: table, columns: columns)
    }
    
    public func insert(_ row: Row) throws {
        let statement = try getInsertStatement()
        try StatementEncoder().encode(row, into: statement)
        var _ = try statement.step()
    }
    
    private var insertStatement: Statement?
    private func getInsertStatement() throws -> Statement {
        if let statement = insertStatement {
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
    
//    public var select: SelectBuilder {
//        SelectBuilder(connection)
//    }
    
}
        
public struct SelectBuilder {
    
}


