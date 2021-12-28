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

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(KeyedContainer<Key>(self, values, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UnkeyedContainer(self, values, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(values, codingPath: codingPath)
    }
}

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let decoder: MultifariousDecoderImpl
    private let values: MultifariousValues
    let codingPath: [CodingKey]

    init(_ decoder: MultifariousDecoderImpl, _ values: MultifariousValues, codingPath: [CodingKey])
    {
        self.decoder = decoder
        self.values = values
        self.codingPath = codingPath
    }

    var allKeys: [Key] {
        /// This is used when decoding dictionaries - pretend that we have one string key with a unique value
        guard let value = values.next(String.self),
            let key = Key(stringValue: value)
        else {
            return []
        }
        return [key]
    }

    func contains(_ key: Key) -> Bool {
        true  // pretend we have every key
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        false  // optional values are never nil
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        if let value = values.next(type) {
            return value
        }
        return try T(from: decoderForKey(key))
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        return try decoderForKey(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return decoderForKey(MultifariousKey("super"))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        return decoderForKey(key)
    }

    private func decoderForKey<K: CodingKey>(_ key: K) -> MultifariousDecoderImpl {
        return MultifariousDecoderImpl(values, codingPath: self.codingPath + [key])
    }
}

private struct UnkeyedContainer: UnkeyedDecodingContainer {
    private let decoder: MultifariousDecoderImpl
    private let values: MultifariousValues
    let codingPath: [CodingKey]

    init(_ decoder: MultifariousDecoderImpl, _ values: MultifariousValues, codingPath: [CodingKey])
    {
        self.decoder = decoder
        self.values = values
        self.codingPath = codingPath
    }

    let count: Int? = 1
    var isAtEnd: Bool {
        currentIndex > 0
    }

    private(set) var currentIndex: Int = 0

    func decodeNil() throws -> Bool {
        return false
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        return try nextDecoder().container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try nextDecoder().unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        return nextDecoder()
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T(from: nextDecoder())
    }

    mutating private func nextDecoder() -> MultifariousDecoderImpl {
        let key = MultifariousKey(currentIndex)
        currentIndex += 1
        return MultifariousDecoderImpl(values, codingPath: self.codingPath + [key])
    }
}

struct SingleValueContainer: SingleValueDecodingContainer {
    private let values: MultifariousValues
    let codingPath: [CodingKey]

    init(_ values: MultifariousValues, codingPath: [CodingKey]) {
        self.values = values
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard let value = values.next(type) else {
            throw ReflectionError.noValues(type)
        }
        return value
    }
}

internal struct MultifariousKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.init(stringValue)
    }

    public init?(intValue: Int) {
        self.init(intValue)
    }

    public init(_ string: String) {
        self.stringValue = string
    }

    internal init(_ int: Int) {
        self.stringValue = "Index \(int)"
        self.intValue = int
    }
}
