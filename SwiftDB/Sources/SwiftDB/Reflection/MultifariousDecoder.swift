import Foundation

/// Produces a sequence `seq` of instances of a `Decodable` type `T`, constructed so that
/// `seq.map(\.p)` is guaranteed to be unique for any property `p` of `T`.
enum MultifariousDecoder {
    static func instances<T: Decodable>(for type: T.Type) throws -> [T] {
        do {
            let cyclers = Cyclers()
            let decoder = MultifariousDecoderImpl(cyclers)
            var instances = [T]()
            while true {
                instances.append(try T(from: decoder))
                cyclers.finishRow()
                if cyclers.hasFinished {
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
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey: Any]()
    private let cyclers: Cyclers

    init(_ cyclers: Cyclers) {
        self.cyclers = cyclers
    }

    private var decodingContainer: Any?

    private(set) var hasMoreInstances = true

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<
        Key
    > {
        guard let decodingContainer = self.decodingContainer else {
            let decodingContainer = CountingContainer<Key>(self, cyclers)
            self.decodingContainer = decodingContainer
            return KeyedDecodingContainer(decodingContainer)
        }

        guard let decodingContainer = decodingContainer as? CountingContainer<Key> else {
            throw InternalError.invalidRecordType(
                "Decoder.container(keyedBy:) called with different key types (\(type))")
        }
        return KeyedDecodingContainer(decodingContainer)
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

private class Cyclers {
    private var valuesByType = [AnyType: AnyValues]()
    private var cyclersByType = [AnyType: ValueCycler]()

    let numericCycler = ValueCycler(AnyValues(NumericValues()))

    private(set) var hasFinished = false

    init() {
        addValues(ArrayOfValues<Bool>([false, true]))
        addValues(ArrayOfValues<String>(["a", "b", "c", "d", "e", "f", "g", "h"]))
        addValues(
            ArrayOfValues<UUID>([
                UUID(uuid: (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0)),
                UUID(uuid: (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1)),
            ]))
        addValues(
            ArrayOfValues<Date>([
                Date(timeIntervalSince1970: 1_234_567_890),
                Date(timeIntervalSince1970: 1_234_567_891),
            ]))
        addValues(
            ArrayOfValues<Data>([
                Data(repeating: 9, count: 10),
                Data(repeating: 8, count: 10),
            ]))
        addValues(
            ArrayOfValues<Decimal>([
                Decimal(100_000),
                Decimal(100_001),
            ]))
    }

    func finishRow() {
        numericCycler.nextRow()
        var hasFinished = numericCycler.hasFinished
        for cycler in cyclersByType.values {
            cycler.nextRow()
            if !cycler.hasFinished {
                hasFinished = false
            }
        }
        self.hasFinished = hasFinished
    }

    func addValues<V: Values, E>(_ values: V) where V.Element == E {
        valuesByType[AnyType(E.self)] = AnyValues(values)
    }

    func getCycler(_ type: Any.Type) -> ValueCycler? {
        if let cycler = cyclersByType[AnyType(type)] {
            return cycler
        }
        guard let values = valuesByType[AnyType(type)] else {
            return nil
        }
        let cycler = ValueCycler(values)
        cyclersByType[AnyType(type)] = cycler
        return cycler
    }
}

private enum FinishRowResult {
    case hasMore
    case finished
}

private class CountingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let decoder: MultifariousDecoderImpl
    private let cyclers: Cyclers

    private var index = 0

    let codingPath = [CodingKey]()

    init(_ decoder: MultifariousDecoderImpl, _ cyclers: Cyclers) {
        self.decoder = decoder
        self.cyclers = cyclers
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
        if let cycler = cyclers.getCycler(type) {
            guard let value = cycler.next() as? T else {
                throw SwiftDBError.unexpected(
                    "Generated values for key \(key.stringValue) were not of the expected type (\(type))"
                )
            }
            return value
        }
        throw ReflectionError.noValues(type)
    }

    private func decodeNumericValue<T: Decodable & Numeric>(_ type: T.Type, forKey key: Key)
        throws -> T
    {
        let next = cyclers.numericCycler.next()
        guard let number = next as? Int8,
            let value = T(exactly: number)
        else {
            throw SwiftDBError.unexpected(
                "NumericValues produced number of the wrong type: \(Swift.type(of: next))")
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
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try decodeNumericValue(type, forKey: key)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try decodeValue(type, forKey: key)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
        fatalError("Not implemented")
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        fatalError("Not implemented")
    }

    func superDecoder() throws -> Decoder {
        fatalError("Not implemented")
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        fatalError("Not implemented")
    }
}
