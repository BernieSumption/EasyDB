import Foundation

/// The encoded representation of an `Encodable` type - essentially an in-memory representation
/// of the JSON data structure produced by `JSONEncoder`
enum Encoded: Hashable {
    case null
    case boolean(Bool)
    case number(Double)
    case string(String)
    case array([Encoded])
    case object([String: Encoded])

    init<T: Encodable>(encoding encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        try self.init(parsing: data)
    }

    init(parsing string: String) throws {
        try self.init(parsing: Data(string.utf8))
    }

    init(parsing data: Data) throws {
        let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        try self.init(fromParsedJson: value)
    }

    private init(fromParsedJson value: Any) throws {
        if let dict = value as? [String: Any] {
            self = .object(try dict.mapValues { try Encoded(fromParsedJson: $0) })
        } else if let array = value as? [Any] {
            self = .array(try array.map { try Encoded(fromParsedJson: $0) })
        } else if let bool = valueAsBool(value) {
            self = .boolean(bool)
        } else if let number = value as? Double {
            self = .number(number)
        } else if let string = value as? String {
            self = .string(string)
        } else if value is NSNull {
            self = .null
        } else {
            throw SwiftDBError.unexpected(message: 
                "JSONSerialization.jsonObject produced unexpected type \(value), \(type(of: value))"
            )
        }
    }

    var propertyPaths: [[String]] {
        switch self {
        case .object(let dict):
            var paths = [[String]]()
            for (key, value) in dict {
                paths.append([key])
                let childPaths = value.propertyPaths.map {
                    [key] + $0
                }
                paths.append(contentsOf: childPaths)
            }
            return paths
        default:
            return []
        }
    }

    /// Return the `JSON` value found by descending into objects using the specified path of property names
    func value<S: RandomAccessCollection>(at path: S) -> Encoded? where S.Element == String {
        guard let firstProperty = path.first else {
            return self
        }
        guard case .object(let dict) = self else {
            return nil
        }
        guard let value = dict[firstProperty] else {
            return nil
        }
        return value.value(at: path.dropFirst())
    }
}

private func valueAsBool(_ value: Any) -> Bool? {
    guard let number = value as? NSNumber else {
        return nil
    }
    /// JSONSerialization converts JSON bools to NSNumbers which will happily convert to
    /// other number types using e.g. `value as? Double`, so we need to check
    /// that the underlying type is boolean
    guard CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else {
        return nil
    }
    return number as? Bool
}
