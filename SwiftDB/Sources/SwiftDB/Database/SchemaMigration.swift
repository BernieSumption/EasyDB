
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
        let sql = SQL()
            .createTable(table, ifNotExists: true)
            .bracketed(raw: columns.map { column in
                SQL.quoteName(column)
            })
            .text
        try connection.execute(sql: sql)
    }
    
    /// Alter `table` to add `column`
    func addColumn(table: String, column: String) throws {
        let sql = SQL().alterTable(table).addColumn(column).text
        try connection.execute(sql: sql)
    }
    
    /// Alter `table` to drop `column`
    func dropColumn(table: String, column: String) throws {
        let sql = SQL().alterTable(table).dropColumn(column).text
        try connection.execute(sql: sql)
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
    func dropIndex(name: String) throws {
        try connection.execute(sql: SQL().dropIndex(name).text)
    }
    
    func getIndexNames(table: String) throws -> [String] {
        return try connection.execute(
            [String].self,
            sql: "SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = ? ORDER BY name",
            parameters: [.text(table)])
    }
    
    /// Ensure that `table` has the defined set of indices
    func migrateIndices(table: String, indices: [Index]) throws {
        let existingNames = Set(try getIndexNames(table: table))
        let expectedNames = Set(indices.map({ $0.name(forTable: table) }))
        let namesToDrop = existingNames.subtracting(expectedNames)
        for name in namesToDrop {
            try dropIndex(name: name)
        }
        let indicesToAdd = indices.filter({ index in
            let name = index.name(forTable: table)
            return !existingNames.contains(name)
        })
        for index in indicesToAdd {
            try addIndex(table: table, index)
        }
    }
}

struct Index: Equatable {
    let parts: [Part]
    let unique: Bool
    
    init(_ parts: [Part], unique: Bool = false) {
        assert(parts.count > 0, "at least one parts required to create an index")
        self.parts = parts
        self.unique = unique
    }
    
    func name(forTable table: String) -> String {
        var result = table
        if unique {
            result += "-unique"
        }
        result += "-"
        result += parts.map(\.name).joined(separator: "-")
        return result
    }
    
    func createSQL(forTable table: String) -> String {
        let columnsSql: [String] = parts.map({ column in
            // TODO: JSON expression when path.count > 1
            var sql = SQL.quoteName(column.path.joined(separator: "."))
            if let collation = column.collation {
                sql += " COLLATE " + SQL.quoteName(collation.name)
            }
            switch column.direction {
            case .ascending:
                sql += " ASC"
            case .descending:
                sql += " DESC"
            case .none:
                break
            }
            return sql
        })
        return SQL()
            .createIndex(name: name(forTable: table), on: table, unique: unique)
            .bracketed(raw: columnsSql)
            .text
    }
    
    struct Part: Equatable {
        let path: [String]
        let collation: Collation?
        let direction: Direction?
        
        init(
            _ path: [String],
            collation: Collation?,
            _ direction: Direction? = nil
        ) {
            self.path = path
            self.direction = direction
            self.collation = collation
        }
        
        var name: String {
            var result = path.joined(separator: ".")
            if let collation = collation {
                result += "-"
                result += collation.name
            }
            if let direction = direction {
                switch direction {
                case .ascending:
                    result += "-asc"
                case .descending:
                    result += "-desc"
                }
            }
            return result
        }
    }
    
    enum Direction: String {
        case ascending
        case descending
    }
}
