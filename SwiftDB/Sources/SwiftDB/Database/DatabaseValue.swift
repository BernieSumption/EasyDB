import Foundation

enum DatabaseValue: Equatable {
    case double(Double)
    case int(Int64)
    case null
    case text(String)
    case blob(Data)

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
        guard case .text(let value) = self else {
            throw DatabaseValueError("expected string got \(self)")
        }
        return value
    }

    init<T: BinaryFloatingPoint>(_ value: T) {
        self = .double(Double(value))
    }
    func decode<T: BinaryFloatingPoint>(as: T.Type) throws -> T {
        guard case .double(let value) = self else {
            throw DatabaseValueError("expected double got \(self)")
        }
        return T(value)
    }

    init<T: BinaryInteger>(_ value: T) {
        // allow 64 bit unsigned integers to overflow into SQLite's signed 64 bit storage
        self = .int(Int64(truncatingIfNeeded: value))
    }
    func decode<T: FixedWidthInteger>(as: T.Type) throws -> T {
        guard case .int(let value) = self else {
            throw DatabaseValueError("expected int got \(self)")
        }
        // reverse the overflow of unsigned 64 bit types
        return T(truncatingIfNeeded: value)
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
