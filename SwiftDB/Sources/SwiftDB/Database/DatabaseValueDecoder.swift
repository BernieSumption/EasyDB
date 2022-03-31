import Foundation

enum DatabaseValueDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from value: DatabaseValue) throws -> T {
        // This looks inefficient, but since T is known at compile time all
        // non-matching conditions will be eliminated by the compiler
        if T.self == Bool.self    { return try value.as(Bool.self) as! T }
        if T.self == String.self  { return try value.as(String.self) as! T }
        if T.self == Double.self  { return try value.as(Double.self) as! T }
        if T.self == Float.self   { return try value.as(Float.self) as! T }
        if T.self == Float16.self { return try value.as(Float16.self) as! T }
        if T.self == Int.self     { return try value.as(Int.self) as! T }
        if T.self == Int8.self    { return try value.as(Int8.self) as! T }
        if T.self == Int16.self   { return try value.as(Int16.self) as! T }
        if T.self == Int32.self   { return try value.as(Int32.self) as! T }
        if T.self == Int64.self   { return try value.as(Int64.self) as! T }
        if T.self == UInt.self    { return try value.as(UInt.self) as! T }
        if T.self == UInt8.self   { return try value.as(UInt8.self) as! T }
        if T.self == UInt16.self  { return try value.as(UInt16.self) as! T }
        if T.self == UInt32.self  { return try value.as(UInt32.self) as! T }
        if T.self == UInt64.self  { return try value.as(UInt64.self) as! T }
        
        if let type = type as? DatabaseValueConvertible.Type {
            return try type.init(from: value) as! T
        }

        do {
            let decoder = DatabaseValueDecoderImpl(value: value, codingPath: [])
            return try T(from: decoder)
        } catch Result.useJsonDecoder {
            let jsonString = try value.as(String.self)
            return try jsonDecoder.decode(T.self, from: Data(jsonString.utf8))
        }
    }
    
    static func singleValueContainer(
        _ value: DatabaseValue,
        codingPath: [CodingKey]
    ) throws -> SingleValueDecodingContainer {
        return try DatabaseValueDecoderImpl(value: value, codingPath: codingPath).singleValueContainer()
    }
}

private struct DatabaseValueDecoderImpl: Decoder {
    let value: DatabaseValue
    let codingPath: [CodingKey]
    
    let userInfo = [CodingUserInfoKey: Any]()

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw Result.useJsonDecoder
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw Result.useJsonDecoder
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(value: value)
    }

    struct SingleValueContainer: SingleValueDecodingContainer {

        let value: DatabaseValue

        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()

        func decodeNil() -> Bool {
            return value == .null
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            return try DatabaseValueDecoder.decode(T.self, from: value)
        }
    }
}

/// An error used to communicate the result of decoding
private enum Result: Error {
    /// The type does not decode from a primitive value and JSON decodingcoding should be used instead
    case useJsonDecoder
}

private let jsonDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
