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
        
        // This looks inefficient, but since T is known at compile time all
        // non-matching conditions will be eliminated by the compiler
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
        
        // TODO: extract into Protocol
        if T.self == Date.self    { return ParameterValue(value as! Date) }
        if T.self == Data.self    { return ParameterValue(value as! Data) }
        
        var result: ParameterValue?
        do {
            let encoder = ParameterValueEncoderImpl(result: { result = $0 })
            try value.encode(to: encoder)
            guard let result = result else {
                throw SwiftDBError.codingError(
                    message: "\(T.self) did not send any data to the encoder",
                    codingPath: [])
            }
            return result
        } catch is UseJsonEncoder {
            let jsonData = try jsonEncoder.encode(value)
            return .text(String(decoding: jsonData, as: UTF8.self))
        }
    }
}

private struct ParameterValueEncoderImpl: Encoder {
    var result: (ParameterValue) -> Void
    
    var codingPath = [CodingKey]()
    var userInfo = [CodingUserInfoKey : Any]()
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return NotImplementedEncoder(error: UseJsonEncoder()).container(keyedBy: type)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return NotImplementedEncoder(error: UseJsonEncoder()).unkeyedContainer()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer(result: result)
    }
    
    struct SingleValueContainer: SingleValueEncodingContainer {
        var result: (ParameterValue) -> Void
        
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey : Any]()
        
        mutating func encodeNil() throws {
            result(.null)
        }
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            result(try ParameterValueEncoder.encode(value))
        }
    }
}

/// An Error thrown to indicate that we should use `JSONEncoder` to encode this value
private struct UseJsonEncoder: Error {}
