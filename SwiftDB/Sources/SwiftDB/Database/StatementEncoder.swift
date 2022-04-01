import Foundation

/// Encodes a value by binding its properties to named parameters of a query
struct StatementEncoder {
    static func encode<T: Encodable>(_ value: T, into statement: Statement) throws {
        try value.encode(to: StatementEncoderImpl(statement))
    }
}

private struct StatementEncoderImpl: Encoder {
    private let statement: Statement
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey: Any]()

    init(_ statement: Statement) {
        self.statement = statement
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(NamedParameterEncodingContainer(statement))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let feature = "providing arrays of parameter values to a statement"
                    + "(currently you must use structs or dictionaries to bind named parameters instead)"
        return NotImplementedEncoder(
            error: SwiftDBError.notImplemented(feature: feature)
        ).unkeyedContainer()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        let feature = "providing single parameter values to a statement"
                    + " (currently you must use structs or dictionaries to bind named parameters instead)"
        return NotImplementedEncoder(
            error: SwiftDBError.notImplemented(feature: feature)
        ).singleValueContainer()
    }
}

private struct NamedParameterEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let statement: Statement
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey: Any]()

    init(_ statement: Statement) {
        self.statement = statement
    }

    mutating func encodeNil(forKey key: Key) throws {
        try bind(.null, to: key)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        try bind(DatabaseValueEncoder.encode(value), to: key)
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try encodeIfPresentHelper(value, forKey: key)
    }

    mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
        try encodeIfPresentHelper(value, forKey: key)
    }

    private mutating func encodeIfPresentHelper<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
        if let value = value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        return StatementEncoderImpl(statement).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return StatementEncoderImpl(statement).unkeyedContainer()
    }

    mutating func superEncoder() -> Encoder {
        return StatementEncoderImpl(statement)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return StatementEncoderImpl(statement)
    }

    func bind(_ value: DatabaseValue, to key: Key) throws {
        try statement.bind(value, to: ":\(key.stringValue)")
    }
}
