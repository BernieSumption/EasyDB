public class Collection<T: Codable> {
    private let connection: Connection
    private let mapper: KeyPathMapper<T>
    private let columns: [String]
    private let table: String
    
    
    internal init(_ type: T.Type, _ connection: Connection) throws {
        self.connection = connection
        self.mapper = try KeyPathMapper(type)
        // TODO: Options API to customise table names
        self.table = String(describing: T.self)
        self.columns = mapper.rootProperties
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This frees up disk space, but is irreversible.
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: connection)
        try migration.ensureTableExists(table: table, columns: columns)
    }
    
    public func insert(_ row: T) throws {
        let statement = try getInsertStatement()
        try StatementEncoder().encode(row, into: statement)
        var _ = try statement.step()
    }
    
    private var insertStatement: Statement?
    private func getInsertStatement() throws -> Statement {
        if let statement = insertStatement {
            return statement
        }
        let columnsSQL = columns.map(quoteName).joined(separator: ", ")
        let parametersSQL = columns.map({ ":" + $0 }).joined(separator: ", ")
        let sql = "INSERT INTO \(quoteName(table)) (\(columnsSQL)) VALUES (\(parametersSQL))"
        let statement = try connection.prepare(sql: sql)
        insertStatement = statement
        return statement
    }
    
}

private func quoteName(_ name: String) -> String {
    return "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

