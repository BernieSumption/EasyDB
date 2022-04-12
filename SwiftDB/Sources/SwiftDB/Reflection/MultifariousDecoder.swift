import Foundation

/// Produces a sequence `seq` of instances of a `Decodable` type `T`, constructed so that
/// `seq.map(\.p)` is guaranteed to be unique for any property `p` of `T`.
enum MultifariousDecoder {
    static func instances<T: Decodable>(for type: T.Type) throws -> [T] {
        do {
            let values = MultifariousValues()
            let decoder = MultifariousDecoderImpl(values, codingPath: [], metadata: nil)
            var instances = [T]()
            while true {
                instances.append(try decodeHelper(T.self, from: decoder))
                values.nextRow()
                if values.hasFinished {
                    return instances
                }
            }
        } catch InternalError.invalidRecordType(let message) {
            throw ReflectionError.invalidRecordType(type, message)
        }
    }

    static func metadata<T: Decodable>(for type: T.Type) throws -> TypeMetadata {
        do {
            let values = MultifariousValues()
            let typeMetadata = TypeMetadata()
            let decoder = MultifariousDecoderImpl(values, codingPath: [], metadata: typeMetadata)
            _ = try decodeHelper(T.self, from: decoder)
            return typeMetadata
        } catch InternalError.invalidRecordType(let message) {
            throw ReflectionError.invalidRecordType(type, message)
        }
    }
}

private enum InternalError: Error {
    case invalidRecordType(String)
}

/// A `Decoder` that produces instances with values from a `MultifariousValues` instance
private struct MultifariousDecoderImpl: Decoder {
    private let values: MultifariousValues
    private let metadata: TypeMetadata?
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    init(_ values: MultifariousValues, codingPath: [CodingKey], metadata: TypeMetadata?) {
        self.values = values
        self.metadata = metadata
        self.codingPath = codingPath
        if let metadata = metadata {
            userInfo = [TypeMetadata.userInfoKey: metadata]
        } else {
            userInfo = [:]
        }
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        if codingPath.count > 0 {
            metadata?.finishTopLevelProperty()
        }
        return KeyedDecodingContainer(KeyedContainer(values, codingPath: codingPath, metadata: metadata))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        metadata?.finishTopLevelProperty()
        return UnkeyedContainer(values, codingPath: codingPath, metadata: metadata)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(values, codingPath: codingPath, metadata: metadata)
    }
}

/// Keyed containers produce values for objects (structs and classes) and dictionaries.
private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let values: MultifariousValues
    private let metadata: TypeMetadata?
    let codingPath: [CodingKey]

    init(_ values: MultifariousValues, codingPath: [CodingKey], metadata: TypeMetadata?)
    {
        self.values = values
        self.codingPath = codingPath
        self.metadata = metadata
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

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        if let value = values.next(type) {
            return value
        }
        let isTopLevelProperty = codingPath.count == 0
        if isTopLevelProperty {
            try metadata?.startTopLevelProperty(propertyName: key.stringValue)
        }
        let result = try decodeHelper(T.self, from: decoderForKey(key))
        if isTopLevelProperty {
            metadata?.finishTopLevelProperty()
        }
        return result
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        metadata?.finishTopLevelProperty()
        return try decoderForKey(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        metadata?.finishTopLevelProperty()
        return try decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        throw SwiftDBError.notImplemented(feature: "Class types or value types that use KeyedContainer.superDecoder()")
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        throw SwiftDBError.notImplemented(feature: "Class types or value types that use KeyedContainer.superDecoder()")
    }

    private func decoderForKey<K: CodingKey>(_ key: K) -> MultifariousDecoderImpl {
        return MultifariousDecoderImpl(values, codingPath: self.codingPath + [key], metadata: metadata)
    }
}

/// Unkeyed contains produce values for arrays and tuples
private struct UnkeyedContainer: UnkeyedDecodingContainer {
    private let values: MultifariousValues
    let codingPath: [CodingKey]
    private let metadata: TypeMetadata?

    init(_ values: MultifariousValues, codingPath: [CodingKey], metadata: TypeMetadata?)
    {
        self.values = values
        self.codingPath = codingPath
        self.metadata = metadata
    }

    /// Unkeyed containers have 2 elements. This is because some types, e.g `[Date: String]`, expect a series
    /// of key/value pairs encoded as alternating elements in an array
    let count: Int? = 2
    var isAtEnd: Bool {
        currentIndex >= 2
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
        if let value = values.next(type) {
            currentIndex += 1
            return value
        }
        return try decodeHelper(T.self, from: nextDecoder())
    }

    mutating private func nextDecoder() -> MultifariousDecoderImpl {
        let key = MultifariousKey(currentIndex)
        currentIndex += 1
        return MultifariousDecoderImpl(values, codingPath: self.codingPath + [key], metadata: metadata)
    }
}

private func decodeHelper<T: Decodable, D: Decoder>(_ type: T.Type, from decoder: D) throws -> T {
    do {
        return try T(from: decoder)
    } catch {
        if error is ReflectionError || error is InternalError {
            throw error  // Don't wrap our internal error types
        }
        throw ReflectionError.decodingError(type, error)
    }
}

struct SingleValueContainer: SingleValueDecodingContainer {
    private let values: MultifariousValues
    let codingPath: [CodingKey]
    private let metadata: TypeMetadata?

    init(_ values: MultifariousValues, codingPath: [CodingKey], metadata: TypeMetadata?) {
        self.values = values
        self.codingPath = codingPath
        self.metadata = metadata
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if let value = values.next(type) {
            return value
        }
        if !(type is IsConfigurationAnnotation.Type) {
            metadata?.finishTopLevelProperty()
        }
        let nextDecoder = MultifariousDecoderImpl(values, codingPath: codingPath, metadata: metadata)
        return try decodeHelper(type, from: nextDecoder)
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
        self.stringValue = int.description
        self.intValue = int
    }
}
