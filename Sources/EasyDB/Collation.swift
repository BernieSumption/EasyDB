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
    /// The default collation sequence for EasyDB - sort strings case-sensitively using Swift's `==` and `<=` operators.
    public static let string = Collation("string") { (lhs, rhs) in
        if lhs == rhs {
            return .orderedSame
        }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    /// Sort unicode strings in a case-insensitive way using Swift's `String.caseInsensitiveCompare(_:)` function
    public static let caseInsensitive = Collation("caseInsensitive") { (lhs, rhs) in
        return lhs.caseInsensitiveCompare(rhs)
    }

    /// Sort unicode strings using localized comparison with Swift's `String.localizedCompare(_:)` function.
    ///
    /// This produces ordering similar to that when you get in the macOS Finder.
    public static let localized = Collation("localized") { (lhs, rhs) in
        return lhs.localizedCompare(rhs)
    }

    /// Sort unicode strings using case-insensitive localized comparison with Swift's `String.localizedCaseInsensitiveCompare(_:)` function
    public static let localizedCaseInsensitive = Collation("localizedCaseInsensitive") { (lhs, rhs) in
        "".localizedCompare("")
        return lhs.localizedCaseInsensitiveCompare(rhs)
    }

    /// The built-in SQLite `binary` collation that compares strings using their in-memory binary representation,
    /// regardless of text encoding. WARNING: this is provided as a performance optimisation or because some
    /// applications may want differentiate between equivalent but differently serialised unicode strings. But for most
    /// real applications it is not a good choice.
    public static let binary = Collation("binary")
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
