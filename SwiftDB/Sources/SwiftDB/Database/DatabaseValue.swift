import Foundation

enum DatabaseValue: Equatable, CustomStringConvertible {
    case double(Double)
    case int(Int64)
    case null
    case text(String)
    case blob(Data)
    
    var description: String {
        switch self {
        case .double: return "double"
        case .int: return "int"
        case .null: return "null"
        case .text: return "text"
        case .blob: return "blob"
        }
    }

    init(_ value: Bool) {
        self = .int(value ? 1 : 0)
    }
    func decode(as: Bool.Type) throws -> Bool {
        return try decode(as: Int64.self) != 0
    }

    init(_ value: String) {
        self = .text(value)
    }
    func decode(as: String.Type) throws -> String {
        switch self {
        case .text(let value):
            return value
        case .double(let value):
            return String(value)
        case .int(let value):
            return String(value)
        case .blob, .null:
            throw DatabaseValueError("expected text got \(self)")
        }
    }

    init<T: BinaryFloatingPoint>(_ value: T) {
        self = .double(Double(value))
    }
    func decode<T: BinaryFloatingPoint>(as: T.Type) throws -> T {
        switch self {
        case .double(let value):
            return T(value)
        case .int(let value):
            return T(value)
        case .blob, .null, .text:
            throw DatabaseValueError("expected double got \(self)")
        }
    }

    init<T: BinaryInteger>(_ value: T) {
        // allow 64 bit unsigned integers to overflow into SQLite's signed 64 bit storage
        self = .int(Int64(truncatingIfNeeded: value))
    }
    func decode<T: FixedWidthInteger>(as: T.Type) throws -> T {
        switch self {
        case .double(let value):
            guard let value = T(exactly: value) else {
                throw DatabaseValueError("could not exactly represent \(value) as \(T.self)")
            }
            return value
        case .int(let value):
            if T.self == UInt64.self || T.self == UInt.self {
                // reverse the overflow applied at encoding time
                return T(truncatingIfNeeded: value)
            }
            guard let value = T(exactly: value) else {
                throw DatabaseValueError("could not exactly represent \(value) as \(T.self)")
            }
            return value
        case .blob, .null, .text:
            throw DatabaseValueError("expected int got \(self)")
        }
    }

    // TODO: move to protocol
    init(_ value: Date) {
        let encoded = iso8601Formatter.string(from: value)
        self = .text(encoded)
    }
    func decode(as: Date.Type) throws -> Date {
        let value = try decode(as: String.self)
        guard let date = iso8601Formatter.date(from: value) else {
            let displayValue = value.count > 30 ? value.prefix(30) + "..." : value
            throw DatabaseValueError("\"\(displayValue)\" is not an ISO 8601 date/time")
        }
        return date
    }

    // TODO: move to protocol
    init(_ value: Data) {
        self = .blob(value)
    }
    func decode(as: Data.Type) throws -> Data {
        guard case .blob(let value) = self else {
            throw DatabaseValueError("expected blob got \(self)")
        }
        return value
    }
}

struct DatabaseValueError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
