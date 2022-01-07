

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
            sql: "SELECT name FROM pragma_table_info(?) ORDER BY name",
            parameters: [.text(table)])
    }
    
    /// Ensure that `table` exists and has the defined columns, adding and removing columns as necessary
    func migrateColumns(table: String, columns: [String]) throws {
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
    
    func addIndex(table: String, _ index: Index) throws {
        try connection.execute(sql: index.createSQL(forTable: table))
    }
    
    func dropIndex(table: String, name: String) throws {
        try connection.execute(sql: "DROP INDEX IF EXISTS \(name)")
    }
    
    func getIndexNames(table: String) throws -> [String] {
        return try connection.execute(
            [String].self,
            sql: "SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = ? ORDER BY name",
            parameters: [.text(table)])
    }
    
    /// Ensure that `table` exists and has the defined set of indices
    func migrateIndexes(table: String, indices: [Index]) throws {
        let existing = Set(try getIndexNames(table: table))
        let expected = Set(indices.map(\.name))
        let namesToDrop = existing.subtracting(expected)
        for name in namesToDrop  {
            try dropIndex(table: table, name: name)
        }
        let indicesToAdd = indices.filter({ !existing.contains($0.name) })
        for index in indicesToAdd {
            try addIndex(table: table, index)
        }
    }
}

struct Index {
    var columns: [Column]
    var unique: Bool
    
    init(columns: [Column], unique: Bool = false) {
        assert(columns.count > 0, "at least one column required to create an index")
        self.columns = columns
        self.unique = unique
    }
    
    init(column: Column, unique: Bool = false) {
        self.init(columns: [column], unique: unique)
    }
    
    var name: String {
        return "swiftdb_" + columns.map({ column in
            switch column.direction {
            case .ascending:
                return "column_\(column.expression)_asc"
            case .descending:
                return "column_\(column.expression)_desc"
            case .none:
                return "column_\(column.expression)"
            }
        }).joined(separator: "_")
    }
    
    func createSQL(forTable: String) -> String {
        let createSql = (unique ? "CREATE UNIQUE" : "CREATE")
        let columnsSql = columns.map({ column in
            var sql = column.expression
            switch column.direction {
            case .ascending:
                sql += " ASC"
            case .descending:
                sql += " DESC"
            case .none:
                break
            }
            return sql
        }).joined(separator: ", ")
        return "\(createSql) INDEX IF NOT EXISTS \(name) ON \(forTable) (\(columnsSql))"
    }
    
    struct Column: ExpressibleByStringLiteral {
        var expression: String
        var direction: Direction?
        
        init(
            _ column: String,
            _ direction: Direction? = nil
        ) {
            self.expression = column
            self.direction = direction
        }
        
        init(stringLiteral: String) {
            self.init(stringLiteral)
        }
    }
    
    enum Direction: String {
        case ascending
        case descending
    }
}


