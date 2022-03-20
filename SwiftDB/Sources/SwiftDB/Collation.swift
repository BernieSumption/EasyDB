import Foundation

/// Define a sorting order for strings
public struct Collation: Equatable {
    
    /// The name of this collation that can be used in SQL queries
    public let name: String
    
    let normalizedName: String
    let compare: SQLiteCustomCollationFunction?
    
    /// Create a collation function with a comparison function that takes two strings and returns a
    /// [comparison result](https://developer.apple.com/documentation/foundation/comparisonresult).
    public init(_ name: String, _ compare: @escaping (String, String) -> ComparisonResult) {
        self.name = name
        self.normalizedName = SQL.normalizeName(name)
        
        self.compare = { (length1, buffer1, length2, buffer2) in
            let string1 = buffer1.unsafelyUnwrapped.toString(length: Int(length1)).unsafelyUnwrapped
            let string2 = buffer2.unsafelyUnwrapped.toString(length: Int(length2)).unsafelyUnwrapped
            return compare(string1, string2)
        }
    }
    
    /// Create a collation function with a name. It should already exist in the database.
    public init(_ name: String) {
        self.name = name
        self.normalizedName = SQL.normalizeName(name)
        self.compare = nil
    }
    
    public static func == (lhs: Collation, rhs: Collation) -> Bool {
        return lhs.normalizedName == rhs.normalizedName
    }
}

typealias SQLiteCustomCollationFunction = (Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> ComparisonResult

extension Collation {
    
    /// The built-in SQLite `BINARY` collation that compares strings using their in-memory binary representation,
    /// regardless of text encoding. This is the default unless an alternative is specified.
    public static let binary = Collation("BINARY")
    
    /// The built-in SQLite `NOCASE` collation that considers ASCII lowercase and uppercase letters to be equivalent
    /// but does not handle unicode case insensitivity
    ///
    /// This is slightly faster than `.caseInsensitive` if you know that your strings are definitely ASCII-only
    public static let asciiCaseInsensitive = Collation("NOCASE")
    
    /// The built-in SQLite `RTRIM` collation - as `.binary` but ignoring trailing whitespace
    public static let ignoreTrailingWhitespace = Collation("RTRIM")
    
    /// Sort unicode strings correctly using Swift's `==` and `<=` operators on `String`
    public static let compare = Collation("SwiftDB_compare") { (a, b) in
        if a == b {
            return .orderedSame
        }
        return a < b ? .orderedAscending : .orderedDescending
    }
    
    /// Sort unicode strings in a case-insensitive way using Swift's `String.caseInsensitiveCompare(_:)` function
    public static let caseInsensitiveCompare = Collation("caseInsensitiveCompare") { (a, b) in
        return a.caseInsensitiveCompare(b)
    }
    
    /// Sort unicode strings using localized comparison with Swift's `String.localizedCompare(_:)` function
    public static let localizedCompare = Collation("localizedCompare") { (a, b) in
        return a.localizedCompare(b)
    }
    
    /// Sort unicode strings using case-insensitive localized comparison with Swift's `String.localizedCaseInsensitiveCompare(_:)` function
    public static let localizedCaseInsensitiveCompare = Collation("localizedCaseInsensitiveCompare") { (a, b) in
        return a.localizedCaseInsensitiveCompare(b)
    }
}

private extension UnsafeRawPointer {
    func toString(length: Int) -> String? {
        return String(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: self),
            length: length,
            encoding: .utf8,
            freeWhenDone: false)
    }
}
