import Foundation

/// A sequence of instances of a type, constructed so that `Discrimination(T.self).instances.map(\.p)`
/// is guaranteed to be unique for any property `p` of type `T`.
///
/// In practice this means that, for example, if a type has five boolean properties then `instances` would need
/// least 3 elements, so that each property can have a unique `[Bool]` associated with it.
struct Discrimination<T: Decodable> {
    private(set) var instances: [T]

    init(_ type: T.Type) throws {
        do {
            let decoder = DiscriminationUtils.CountingDecoder()
            instances = []
            while let instance = try decoder.nextInstance(T.self) {
                instances.append(instance)
            }
        } catch InternalDiscriminationError.invalidRecordType(let message) {
            throw DiscriminationError.invalidRecordType(type, message)
        }
    }

}

enum DiscriminationError: Error, CustomStringConvertible {
    case noValues(Any.Type)
    case invalidRecordType(Any.Type, String)

    public var description: String {
        switch self {
        case .noValues(let type):
            // TODO: when we have an API for providing values, add it to this error message
            return
                "Could not discriminate properties of type \(type) because no values were provided"
        case .invalidRecordType(let type, let message):
            return "\(type) can't be used as a record type: \(message)"
        }
    }
}


private enum InternalDiscriminationError: Error {
    case invalidRecordType(String)
}

enum DiscriminationUtils {
    
    class CountingDecoder: Decoder {
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()

        private var decodingContainer: Any?  // KeyedDecodingContainer
        private var onContainerInstanceFinish: (() -> InstanceFinishResult)?

        private(set) var hasMoreInstances = true

        func nextInstance<T: Decodable>(_ type: T.Type) throws -> T? {
            guard hasMoreInstances else {
                return nil
            }

            let instance = try T(from: self)

            guard let onCounterInstanceFinish = onContainerInstanceFinish else {
                throw SwiftDBError.unexpected(
                    "\(type)(from decoder: Decoder) did not call decoder.container(keyedBy:)")
            }
            let result = onCounterInstanceFinish()
            hasMoreInstances = result == .greaterThanCount
            if result == .one {
                return nil
            }
            return instance
        }

        func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
        {
            guard let decodingContainer = self.decodingContainer else {
                let decodingContainer = CountingContainer<Key>(self)
                self.decodingContainer = decodingContainer
                self.onContainerInstanceFinish = decodingContainer.onInstanceFinish
                return KeyedDecodingContainer(decodingContainer)
            }

            guard let decodingContainer = decodingContainer as? CountingContainer<Key> else {
                throw InternalDiscriminationError.invalidRecordType(
                    "Decoder.container(keyedBy:) called with different key types (\(type))")
            }
            return KeyedDecodingContainer(decodingContainer)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw InternalDiscriminationError.invalidRecordType(
                "array-like (unkeyed) Decodable types are not supported")
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            throw InternalDiscriminationError.invalidRecordType(
                "single value Decodable types are not supported")
        }
    }

    private class CountingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private let decoder: CountingDecoder

        private var index = 0

        let codingPath = [CodingKey]()

        var valuesByType = [AnyType: AnyValues]()
        var cyclersByType = [AnyType: Counter]()

        init(_ decoder: CountingDecoder) {
            self.decoder = decoder
            addValues(ArrayOfValues<Bool>([false, true]))
            addValues(ArrayOfValues<String>(["a", "b", "c", "d", "e", "f", "g", "h"]))
            addValues(NumericValues(Double.self))
            addValues(NumericValues(Float.self))
            addValues(NumericValues(Int.self))
            addValues(NumericValues(Int8.self))
            addValues(NumericValues(Int16.self))
            addValues(NumericValues(Int32.self))
            addValues(NumericValues(Int64.self))
            addValues(NumericValues(UInt.self))
            addValues(NumericValues(UInt8.self))
            addValues(NumericValues(UInt16.self))
            addValues(NumericValues(UInt32.self))
            addValues(NumericValues(UInt64.self))
        }

        func onInstanceFinish() -> InstanceFinishResult {
            let cyclerResults = cyclersByType.values.map({ $0.onInstanceFinish() })
            if cyclerResults.contains(where: { $0 == .greaterThanCount }) {
                return .greaterThanCount
            }
            if cyclerResults.contains(where: { $0 == .greaterThanOneLessThanCount }) {
                return .greaterThanOneLessThanCount
            }
            return .one
        }

        func addValues<V: Values, E>(_ values: V) where V.Element == E {
            valuesByType[AnyType(E.self)] = AnyValues(values)
        }

        /// We rely on this not being used by any target Decodable types, since we don't have a list of keys in advance
        var allKeys: [Key] {
            return []
        }

        func contains(_ key: Key) -> Bool {
            true  // we have every key
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            false  // and no value is nil
        }

        private func decodeValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let cycler = try getCycler(type)
            guard let value = cycler.next() as? T else {
                throw SwiftDBError.unexpected(
                    "Generated values for key \(key) were not of the expected type (\(type))")
            }
            print("\(key.stringValue)=\(value)")
            return value
        }

        private func getCycler(_ type: Any.Type) throws -> Counter {
            if let cycler = cyclersByType[AnyType(type)] {
                return cycler
            }
            guard let values = valuesByType[AnyType(type)] else {
                throw DiscriminationError.noValues(type)
            }
            let cycler = Counter(values)
            cyclersByType[AnyType(type)] = cycler
            return cycler
        }

        //

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

    /// Cycles through each value of a `Values`
    class Counter {
        private let values: AnyValues

        private var item = 0
        private var runLength = 1
        private var hasFinished = false

        init(_ values: AnyValues) {
            self.values = values
        }

        func onInstanceFinish() -> InstanceFinishResult {
            let result: InstanceFinishResult =
                item <= 1
                ? .one
            : (runLength * values.count < item
                    ? .greaterThanCount
                    : .greaterThanOneLessThanCount)
            item = 0
            if result == .greaterThanCount {
                runLength *= values.count
            } else {
                hasFinished = true
            }
            return result
        }

        func next() -> Any {
            guard !hasFinished else {
                return values[0]
            }
            let index = (item / runLength) % values.count
            item += 1
            return values[index]
        }
    }

    enum InstanceFinishResult {
        case greaterThanCount
        case greaterThanOneLessThanCount
        case one
    }
}
