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
    let userInfo = [CodingUserInfoKey : Any]()
    
    init(_ statement: Statement) {
        self.statement = statement
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(NamedParameterEncodingContainer(statement))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return NotImplementedEncoder(
            error: SwiftDBError.notImplemented(feature: "providing arrays of parameter values to a statement (currently you must use structs or dictionaries to bind named parameters instead)")
        ).unkeyedContainer()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return NotImplementedEncoder(
            error: SwiftDBError.notImplemented(feature: "providing single parameter values to a statement (currently you must use structs or dictionaries to bind named parameters instead)")
        ).singleValueContainer()
    }
}

private struct NamedParameterEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let statement: Statement
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey : Any]()
    
    init(_ statement: Statement) {
        self.statement = statement
    }
    
    mutating func encodeNil(forKey key: Key) throws {
        try bind(.null, to: key)
    }
    
    mutating func encode(_ value: Bool, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: String, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Double, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Float, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Int, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Int8, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Int16, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: Int64, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: UInt, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        try bind(ParameterValue(value), to: key)
    }
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // IMPORTANT: any special cases here need matching special cases
        // in StatementDecoder.decode<T>(_:forKey:)
        if let value = value as? _OptionalProtocol, value.isNil {
            try encodeNil(forKey: key)
        }
        else if let value = value as? Data {
            try bind(ParameterValue(value), to: key)
        }
        else if let value = value as? String {
            try bind(ParameterValue(value), to: key)
        }
        else if let value = value as? Date {
            try bind(ParameterValue(value), to: key)
        }
        else {
            try bind(ParameterValueEncoder.encode(value), to: key)
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
    
    func bind(_ value: ParameterValue, to key: Key) throws {
        try statement.bind(value, to: ":\(key.stringValue)")
    }
    
}

private protocol _OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional : _OptionalProtocol {
    var isNil: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}
