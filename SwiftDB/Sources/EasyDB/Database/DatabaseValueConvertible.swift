import Foundation

/// Types should conform to `DatabaseValueConvertible` to use a different
/// database representation than would be provided by their `Codable` implementation.
///
/// For example, `Date` encodes to a single `Double` - the number of seconds since
/// the start of the year 2000. EasyDB uses `DatabaseValueConvertible` internally
/// to use ISO 8601 instead.
public protocol DatabaseValueConvertible {
    /// convert an instance to its database representation
    var databaseValue: DatabaseValue { get }

    /// construct an instance from its database representation
    init(from value: DatabaseValue) throws
}

private var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension Date: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        .text(iso8601Formatter.string(from: self))
    }

    public init(from value: DatabaseValue) throws {
        let string = try value.as(String.self)
        guard let date = iso8601Formatter.date(from: string) else {
            let displayValue = string.count > 30 ? string.prefix(30) + "..." : string
            throw DatabaseValueError("\"\(displayValue)\" is not an ISO 8601 date/time")
        }
        self = date
    }
}

extension Data: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        .blob(self)
    }

    public init(from value: DatabaseValue) throws {
        self = try value.as(Data.self)
    }
}
