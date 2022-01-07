

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
    
    struct ColumnIndex {
        var column: String
        var direction: Direction?
        var collation: String?
        
        init(
            _ column: String,
            direction: Direction? = nil,
            collation: String? = nil
        ) {
            self.column = column
            self.direction = direction
            self.collation = collation
        }
        
        internal var nameFragment: String {
            var name = column
            if let direction = direction {
                name += "_\(direction.rawValue.lowercased())"
            }
            return name
        }
        
        internal var sqlFragment: String {
            var sql = "column_\(column)"
            if let direction = direction {
                sql += " \(direction.rawValue)"
            }
            return sql
        }
    }
    
    enum Direction: String {
        case ascending = "ASC"
        case descending = "DESC"
    }
    
    func addIndex(table: String, column: ColumnIndex, unique: Bool = false) throws {
        try addIndex(table: table, columns: [column], unique: unique)
    }
    
    func addIndex(table: String, columns: [ColumnIndex], unique: Bool = false) throws {
        assert(columns.count > 0, "at least one column required to create an index")
        let name = "_swiftdb_" + columns.map(\.nameFragment).joined(separator: "_")
        let createSql = unique ? "CREATE UNIQUE" : "CREATE"
        let columnsSql = columns.map(\.sqlFragment).joined(separator: ", ")
        try connection.execute(sql: "\(createSql) INDEX IF NOT EXISTS \(name) ON \(table) (\(columnsSql))")
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
