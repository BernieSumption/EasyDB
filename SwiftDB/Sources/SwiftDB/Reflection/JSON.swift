import Foundation

enum JSON: Hashable {
    
    init<T: Encodable>(from encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        try self.init(from: data)
    }
    
    init(from string: String) throws {
        try self.init(from: Data(string.utf8))
    }
    
    init(from data: Data) throws {
        print(String(decoding: data, as: UTF8.self))
        let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        try self.init(fromParsedJson: value)
    }
    
    private init(fromParsedJson value: Any) throws {
        if let dict = value as? [String: Any] {
            self = .object(try dict.mapValues { try JSON(fromParsedJson: $0) })
        } else if let array = value as? [Any] {
            self = .array(try array.map { try JSON(fromParsedJson: $0) })
        } else if let bool = valueAsBool(value) {
            self = .boolean(bool)
        } else if let number = value as? Double {
            self = .number(number)
        } else if let string = value as? String {
            self = .string(string)
        } else if value is NSNull {
            self = .null
        } else {
            throw SwiftDBError.unexpected("JSONSerialization.jsonObject produced unexpected type \(value), \(type(of: value))")
        }
    }

    case null
    case boolean(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object([String: JSON])
}

func valueAsBool(_ value: Any) -> Bool? {
    guard let number = value as? NSNumber else {
        return nil
    }
    // JSONSerialization stores bools as NSNumbers which will happily convert to
    // integers, so we need to check that the underlying type is boolean
    guard CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else {
        return nil
    }
    return number as? Bool
}

/// Test: parse floats and ints
///
