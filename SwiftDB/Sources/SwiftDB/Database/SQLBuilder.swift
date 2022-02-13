
// TODO should be immutable struct where methods return new instances
class SQL: CustomStringConvertible {
    private(set) var text = ""
    var description: String { text }
    
    func select() -> Self {
        return raw("SELECT")
    }
    
    func from(_ table: String) -> Self {
        return raw("FROM").quotedName(table)
    }
    
    func limit(_ limit: Int) -> Self {
        return raw("LIMIT \(limit)")
    }
    
    func createTable(_ table: String, ifNotExists: Bool = false, columns: [String]) -> Self {
        return raw("CREATE TABLE")
            .raw("IF NOT EXISTS", if: ifNotExists)
            .quotedName(table)
            .bracketed(quotedNames: columns)
    }
    
    func insertInto(_ table: String, columns: [String]) -> Self {
        return raw("INSERT INTO").quotedName(table).bracketed(quotedNames: columns)
    }
    
    func alterTable(_ table: String) -> SQL {
        return raw("ALTER TABLE").quotedName(table)
    }
    
    func addColumn(_ column: String) -> SQL {
        return raw("ADD COLUMN").quotedName(column)
    }
    
    func dropColumn(_ column: String) -> SQL {
        return raw("DROP COLUMN").quotedName(column)
    }
    
    func createIndex(name: String, on table: String, unique: Bool = false) -> SQL {
        return raw("CREATE")
            .raw("UNIQUE", if: unique)
            .raw("INDEX")
            .quotedName(name)
            .raw("ON")
            .quotedName(table)
    }
    
    func dropIndex(_ name: String) -> SQL {
        return raw("DROP INDEX").quotedName(name)
    }
    
    func quotedName(_ name: String) -> Self {
        return raw(SQL.quoteName(name))
    }
    
    func quotedNames(_ names: [String]) -> Self {
        return raw(names.map(SQL.quoteName).joined(separator: ", "))
    }
    
    func namedParameter(_ name: String) -> Self {
        return raw(":").raw(name)
    }
    
    func bracketed(quotedNames names: [String]) -> Self {
        return raw("(")
            .quotedNames(names)
            .raw(")")
    }
    
    func bracketed(namedParameters: [String]) -> Self {
        return raw("(")
            .raw(namedParameters.map({ ":" + $0 }).joined(separator: ", "))
            .raw(")")
    }
    
    func bracketed(raw fragments: [String]) -> Self {
        return raw("(")
            .raw(fragments.joined(separator: ", "))
            .raw(")")
    }
    
    func values() -> Self {
        return raw("VALUES")
    }
    
    func raw(_ part: String, if condition: Bool = true) -> Self {
        if text != "" {
            text.append(" ")
        }
        if condition {
            text.append(part)
        }
        return self
    }
    
    static func quoteName(_ name: String) -> String {
        return "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

