import Foundation

/// Produces a sequence `seq` of instances of a `Decodable` type `T`, constructed so that
/// `seq.map(\.p)` is guaranteed to be unique for any property `p` of `T`.
enum MultifariousDecoder {
    static func instances<T: Decodable>(for type: T.Type) throws -> [T] {
        do {
            let values = MultifariousValues()
            let decoder = MultifariousDecoderImpl(values, codingPath: [])
            var instances = [T]()
            while true {
                instances.append(try T(from: decoder))
                values.nextRow()
                if values.hasFinished {
                    return instances
                }
            }
        } catch InternalError.invalidRecordType(let message) {
            throw ReflectionError.invalidRecordType(type, message)
        }
    }
}

private enum InternalError: Error {
    case invalidRecordType(String)
}

private class MultifariousDecoderImpl: Decoder {
    private let values: MultifariousValues
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey: Any]()

    init(_ values: MultifariousValues, codingPath: [CodingKey]) {
        self.values = values
        self.codingPath = codingPath
    }

    private(set) var hasMoreInstances = true

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(KeyedContainer<Key>(self, values, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw InternalError.invalidRecordType(
            "array-like (unkeyed) Decodable types are not supported")
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw InternalError.invalidRecordType(
            "single value Decodable types are not supported")
    }
}


private class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let decoder: MultifariousDecoderImpl
    private let values: MultifariousValues
    let codingPath: [CodingKey]

    private var index = 0

    init(_ decoder: MultifariousDecoderImpl, _ values: MultifariousValues, codingPath: [CodingKey]) {
        self.decoder = decoder
        self.values = values
        self.codingPath = codingPath
    }

    var allKeys: [Key] {
        /// This is used when decoding types that do not know their keys in advance, like Dictionaries.
        /// We return an empty array so all decoded Dictionaries will be empty.
        return []
    }

    func contains(_ key: Key) -> Bool {
        true  // we have every key
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        false  // optional values are never nil
    }

    private func decodeValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let value = values.next(type) else {
            throw ReflectionError.noValues(type)
        }
        return value
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeValue(type, forKey: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try decodeValue(type, forKey: key)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try decodeValue(type, forKey: key)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        return decoderForKey(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return decoderForKey(_JSONK).unkeyedContainer()
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        fatalError("Not implemented")
    }
    
    private func decoderForKey(_ key: K) throws -> MultifariousDecoderImpl {
        return MultifariousDecoderImpl(values, codingPath: self.codingPath + [key])
    }
}

private struct StringKey: CodingKey {
    let intValue: Int? = nil
    var stringValue: String
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init(_ stringValue: String) {
        self.stringValue = stringValue
    }
}
