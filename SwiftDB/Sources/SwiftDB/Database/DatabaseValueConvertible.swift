import Foundation


public protocol DatabaseValueConvertible {
    var databaseValue: DatabaseValue { get }
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
        let string = try value.decode(as: String.self)
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
        self = try value.decode(as: Data.self)
    }
}
