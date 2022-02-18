import Foundation

public enum DatabaseValue: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case double(Double)
    case int(Int64)
    case null
    case text(String)
    case blob(Data)
    
    public var description: String {
        switch self {
        case .double: return "double"
        case .int: return "int"
        case .null: return "null"
        case .text: return "text"
        case .blob: return "blob"
        }
    }
    
    public var debugDescription: String {
        switch self {
        case .double(let value): return "double(\(value))"
        case .int(let value): return "int(\(value))"
        case .null: return "null"
        case .text(let value):
            let displayValue = value.count > 100 ? value.prefix(100) + "..." : value
            return "text(\(displayValue))"
        case .blob(let value): return "blob(\(value))"
        }
    }

    /// Create an int value to represent a boolean.
    ///
    /// `false` and `true` are represented as integers `0` and `1` because
    /// SQLite has no native boolean type)
    public init(_ value: Bool) {
        self = .int(value ? 1 : 0)
    }
    /// Get this value as a Bool or throw an error if it is not exactly `0` or `1`
    public func `as`(_: Bool.Type) throws -> Bool {
        let value = try self.as(Int64.self)
        switch value {
        case 0: return false
        case 1: return true
        default: throw DatabaseValueError("expected 0 or 1 got \(value)")
        }
    }

    
    /// Create a text value
    public init(_ value: String) {
        self = .text(value)
    }
    /// Get this value as a String
    ///
    /// - text is returned as-is
    /// - int and double values are converted to String
    /// - blob and null values throw an error
    public func `as`(_: String.Type) throws -> String {
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

    /// Create a double value
    public init<T: BinaryFloatingPoint>(_ value: T) {
        self = .double(Double(value))
    }
    /// Get this value as a floating point type `T`
    ///
    /// - double and int values are converted to `T`
    /// - blob, text and null values throw an error
    public func `as`<T: BinaryFloatingPoint>(_: T.Type) throws -> T {
        switch self {
        case .double(let value):
            return T(value)
        case .int(let value):
            return T(value)
        case .blob, .null, .text:
            throw DatabaseValueError("expected double got \(self)")
        }
    }

    /// Create an int value
    public init<T: BinaryInteger>(_ value: T) {
        // allow 64 bit unsigned integers to overflow into SQLite's signed 64 bit storage
        self = .int(Int64(truncatingIfNeeded: value))
    }
    /// Get this value as an integer type `T`
    ///
    /// - double and int values are converted to `T` and an error is thrown if `T` is not large or precise enough to hold the value
    /// - blob, text and null values throw an error
    public func `as`<T: FixedWidthInteger>(_: T.Type) throws -> T {
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
    
    /// Create a blob value
    public init(_ value: Data) {
        self = .blob(value)
    }
    /// Get this value as a `Data`
    ///
    /// - blob values return their data
    /// - int, double, text and null values throw an error
    public func `as`(_: Data.Type) throws -> Data {
        switch self {
        case .blob(let value):
            return value
        case .text, .int, .double, .null:
            throw DatabaseValueError("expected data got \(self)")
        }
    }

    init(_ value: DatabaseValueConvertible) {
        self = value.databaseValue
    }
    func `as`<T: DatabaseValueConvertible>(_: T.Type) throws -> T {
        return try T(from: self)
    }
}

struct DatabaseValueError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
