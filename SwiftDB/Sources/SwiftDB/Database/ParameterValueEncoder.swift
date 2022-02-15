import Foundation

private let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}()

private let jsonDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

/// Encodes a value as a `ParameterValue` for storage in the database
///
/// Types that encode themselves as single strings or numbers are stored directly, other
/// types are represented as JSON strings
struct ParameterValueEncoder {
    
    static func encode<T: Encodable>(_ value: T) throws -> ParameterValue {
        
        // This looks inefficient, but since T is known at compile time all non-matching
        // conditions will be eliminated by the compiler
        if T.self == Date.self    { return ParameterValue(value as! Date) }
        if T.self == Data.self    { return ParameterValue(value as! Data) }
        if T.self == Bool.self    { return ParameterValue(value as! Bool) }
        if T.self == String.self  { return ParameterValue(value as! String) }
        if T.self == Double.self  { return ParameterValue(value as! Double) }
        if T.self == Float.self   { return ParameterValue(value as! Float) }
        if T.self == Float16.self { return ParameterValue(value as! Float16) }
        if T.self == Int.self     { return ParameterValue(value as! Int) }
        if T.self == Int8.self    { return ParameterValue(value as! Int8) }
        if T.self == Int16.self   { return ParameterValue(value as! Int16) }
        if T.self == Int32.self   { return ParameterValue(value as! Int32) }
        if T.self == Int64.self   { return ParameterValue(value as! Int64) }
        if T.self == UInt.self    { return ParameterValue(value as! UInt) }
        if T.self == UInt8.self   { return ParameterValue(value as! UInt8) }
        if T.self == UInt16.self  { return ParameterValue(value as! UInt16) }
        if T.self == UInt32.self  { return ParameterValue(value as! UInt32) }
        if T.self == UInt64.self  { return ParameterValue(value as! UInt64) }
        
        do {
            let encoder = ParameterValueEncoderImpl()
            try value.encode(to: encoder)
            throw SwiftDBError.codingError(
                message: "\(T.self) did not send any data to the encoder",
                codingPath: [])
        } catch EncodeResult.result(let value) {
            return value
        } catch EncodeResult.useJsonEncoder {
            let jsonData = try jsonEncoder.encode(value)
            return .text(String(decoding: jsonData, as: UTF8.self))
        }
    }
}

private struct ParameterValueEncoderImpl: Encoder {
    var codingPath = [CodingKey]()
    var userInfo = [CodingUserInfoKey : Any]()
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return NotImplementedEncoder(error: EncodeResult.useJsonEncoder).container(keyedBy: type)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return NotImplementedEncoder(error: EncodeResult.useJsonEncoder).unkeyedContainer()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer()
    }
    
    struct SingleValueContainer: SingleValueEncodingContainer {
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey : Any]()
        
        mutating func encodeNil() throws {
            throw EncodeResult.result(.null)
        }
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            let encoded = try ParameterValueEncoder.encode(value)
            throw EncodeResult.result(encoded)
        }
    }
}

private enum EncodeResult: Error {
    case useJsonEncoder
    case result(ParameterValue)
}
