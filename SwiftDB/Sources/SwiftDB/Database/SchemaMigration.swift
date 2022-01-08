

struct SchemaMigration {
    private let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    /// Create `table` if it does not already exist
    ///
    /// Note: this method will not alter the columns of existing tables if they are different to `columns`
    func ensureTableExists(table: String, columns: [String]) throws {
        assert(columns.count > 0, "at least one column required to create a table")
        let columnsSql = columns.map(quoteName).joined(separator: ", ")
        try connection.execute(sql: "CREATE TABLE IF NOT EXISTS \(quoteName(table)) (\(columnsSql))")
    }
    
    /// Alter `table` to add `column`
    func addColumn(table: String, column: String) throws {
        try connection.execute(sql: "ALTER TABLE \(quoteName(table)) ADD COLUMN \(quoteName(column))")
    }
    
    /// Alter `table` to drop `column`
    func dropColumn(table: String, column: String) throws {
        try connection.execute(sql: "ALTER TABLE \(quoteName(table)) DROP COLUMN \(quoteName(column))")
    }
    
    /// Return a list of column names on `table`
    func getColumns(table: String) throws -> [String] {
        return try connection.execute(
            [String].self,
            sql: "SELECT name FROM pragma_table_info(?) ORDER BY name",
            parameters: [.text(table)])
    }
    
    /// Ensure that `table` exists and has the defined columns, adding and removing columns as necessary
    func migrateColumns(table: String, columns: [String]) throws {
        try ensureTableExists(table: table, columns: columns)
        let existing = Set(try getColumns(table: table))
        let expected = Set(columns)
        for add in expected.subtracting(existing) {
            try addColumn(table: table, column: add)
        }
        for drop in existing.subtracting(expected) {
            try dropColumn(table: table, column: drop)
        }
    }
    
    /// Add an index to `table`
    func addIndex(table: String, _ index: Index) throws {
        try connection.execute(sql: index.createSQL(forTable: table))
    }
    
    /// Remove an index from `table`
    func dropIndex(table: String, name: String) throws {
        try connection.execute(sql: "DROP INDEX \(quoteName(name))")
    }
    
    func getIndexNames(table: String) throws -> [String] {
        return try connection.execute(
            [String].self,
            sql: "SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = ? ORDER BY name",
            parameters: [.text(table)])
    }
    
    /// Ensure that `table` has the defined set of indices
    func migrateIndices(table: String, indices: [Index]) throws {
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
    var parts: [Part]
    var unique: Bool
    
    init(_ parts: [Part], unique: Bool = false) {
        assert(parts.count > 0, "at least one parts required to create an index")
        self.parts = parts
        self.unique = unique
    }
    
    var name: String {
        return "swiftdb_" + parts.map({ column in
            let path = column.path.joined(separator: ".")
            switch column.direction {
            case .ascending:
                return "column_\(path)_asc"
            case .descending:
                return "column_\(path)_desc"
            case .none:
                return "column_\(path)"
            }
        }).joined(separator: "_")
    }
    
    func createSQL(forTable: String) -> String {
        let createSql = (unique ? "CREATE UNIQUE" : "CREATE")
        let columnsSql = parts.map({ column in
            // TODO: JSON expression when path.count > 1
            var sql = quoteName(column.path.joined(separator: "."))
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
        return "\(createSql) INDEX \(quoteName(name)) ON \(quoteName(forTable)) (\(columnsSql))"
    }
    
    struct Part {
        var path: [String]
        var direction: Direction?
        
        init(
            _ path: [String],
            _ direction: Direction? = nil
        ) {
            self.path = path
            self.direction = direction
        }
    }
    
    enum Direction: String {
        case ascending
        case descending
    }
}

private func quoteName(_ name: String) -> String {
    return "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
