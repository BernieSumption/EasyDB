

struct SQL: CustomStringConvertible {
    let text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    var description: String { text }
    
    func limit(_ limit: Int) -> Self {
        return raw("LIMIT \(limit)")
    }
    
    func createTable(_ table: String, ifNotExists: Bool = false) -> Self {
        return raw("CREATE TABLE")
            .raw("IF NOT EXISTS", if: ifNotExists)
            .quotedName(table)
    }
    
    func insertInto(_ table: String, columns: [String], onConflict: OnConflict?) -> Self {
        return raw("INSERT")
            .raw("OR REPLACE", if: onConflict == .replace)
            .raw("OR IGNORE", if: onConflict == .ignore)
            .raw("INTO")
            .quotedName(table)
            .bracketed(quotedNames: columns)
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
    
    func createIndex(name: String, on table: String, unique: Bool) -> SQL {
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
        guard condition else {
            return self
        }
        var newText = text
        if newText != "" {
            newText.append(" ")
        }
        newText.append(part)
        return SQL(text: newText)
    }
    
    static func quoteName(_ name: String) -> String {
        // Use backticks to quote names, even though they're non-standard SQL, because
        // double quotes (as required by the SQL standard) will be magically resolved
        // to a string literal if the identifier doesn't exist, whereas we want use of
        // undefined identifiers to be an error
        // https://sqlite.org/lang_keywords.html
        return "`" + name.replacingOccurrences(of: "`", with: "``") + "`"
    }
    
    /// Convert lowercase ASCII characters to uppercase without affecting non-ASCII unicode characters. This matches
    /// the process used by SQLite to compare strings for case-insensitive equality (`sqlite3_stricmp`)
    static func normalizeName(_ name: String) -> String {
        var result = ""
        result.reserveCapacity(name.count)
        for char in name {
            if char.isASCII {
                result.append(char.uppercased())
            } else {
                result.append(char)
            }
        }
        return result
    }
}

