

struct SchemaMigration {
    private let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func createIfNotExists(table: String, columns: [String]) throws {
        assert(columns.count > 0, "at least one column required to create a table")
        let columnsSql = columns.joined(separator: ", ")
        try connection.execute(sql: "CREATE TABLE IF NOT EXISTS \(table) (\(columnsSql))")
    }
    
    func addColumn(table: String, column: String) throws {
        try connection.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column)")
    }
    
    func dropColumn(table: String, column: String) throws {
        try connection.execute(sql: "ALTER TABLE \(table) DROP COLUMN \(column)")
    }
    
    func getColumns(table: String) throws -> [String] {
        return try connection.execute(
            [String].self,
            sql: "select name from pragma_table_info('foo') ORDER BY name")
    }
    
    /// Ensure that `table` exists and has the defined columns, adding and removing columns as necessary
    func migrate(table: String, columns: [String]) throws {
        try createIfNotExists(table: table, columns: columns)
        let existing = Set(try getColumns(table: table))
        let expected = Set(columns)
        for add in expected.subtracting(existing) {
            try addColumn(table: table, column: add)
        }
        for drop in existing.subtracting(expected) {
            try dropColumn(table: table, column: drop)
        }
    }
}
