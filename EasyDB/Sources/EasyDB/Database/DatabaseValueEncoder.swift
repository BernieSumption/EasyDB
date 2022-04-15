import Foundation

/// Encodes a value as a `DatabaseValue` for storage in the database
///
/// Types that encode themselves as single strings or numbers are stored directly, other
/// types are represented as JSON strings
struct DatabaseValueEncoder {

    static func encode<T: Encodable>(_ value: T) throws -> DatabaseValue {
        // This looks inefficient, but since T is known at compile time all
        // non-matching conditions will be eliminated by the compiler
        // Disable force cast lint rules because in this instance they are safe and unavoidable
        // swiftlint:disable force_cast
        if T.self == Bool.self    { return DatabaseValue(value as! Bool) }
        if T.self == String.self  { return DatabaseValue(value as! String) }
        if T.self == Double.self  { return DatabaseValue(value as! Double) }
        if T.self == Float.self   { return DatabaseValue(value as! Float) }
        if T.self == Float16.self { return DatabaseValue(value as! Float16) }
        if T.self == Int.self     { return DatabaseValue(value as! Int) }
        if T.self == Int8.self    { return DatabaseValue(value as! Int8) }
        if T.self == Int16.self   { return DatabaseValue(value as! Int16) }
        if T.self == Int32.self   { return DatabaseValue(value as! Int32) }
        if T.self == Int64.self   { return DatabaseValue(value as! Int64) }
        if T.self == UInt.self    { return DatabaseValue(value as! UInt) }
        if T.self == UInt8.self   { return DatabaseValue(value as! UInt8) }
        if T.self == UInt16.self  { return DatabaseValue(value as! UInt16) }
        if T.self == UInt32.self  { return DatabaseValue(value as! UInt32) }
        if T.self == UInt64.self  { return DatabaseValue(value as! UInt64) }

        if let value = value as? DatabaseValueConvertible {
            return value.databaseValue
        }
        // swiftlint:enable force_cast

        do {
            let encoder = DatabaseValueEncoderImpl()
            try value.encode(to: encoder)
            throw EasyDBError.codingError(
                message: "\(T.self) did not send any data to the encoder",
                codingPath: [])
        } catch Result.useJsonEncoder {
            let jsonData = try jsonEncoder.encode(value)
            return .text(String(decoding: jsonData, as: UTF8.self))
        } catch Result.value(let value) {
            return value
        }
    }

    static func encodeAll<T: Encodable>(_ values: [T]) throws -> [DatabaseValue] {
        return try values.map(encode)
    }
}

private struct DatabaseValueEncoderImpl: Encoder {
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey: Any]()

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        return NotImplementedEncoder(error: Result.useJsonEncoder).container(keyedBy: type)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return NotImplementedEncoder(error: Result.useJsonEncoder).unkeyedContainer()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer()
    }

    struct SingleValueContainer: SingleValueEncodingContainer {
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()

        mutating func encodeNil() throws {
            throw Result.value(.null)
        }

        mutating func encode<T: Encodable>(_ value: T) throws {
            let value = try DatabaseValueEncoder.encode(value)
            throw Result.value(value)
        }
    }
}

/// Not really an error - this type is used to communicate the result of database value encoding
private enum Result: Error {
    /// The type does not encode to a primitive value and JSON encoding should be used instead
    case useJsonEncoder

    /// The type was successfully encoded
    case value(DatabaseValue)
}

private let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}()
