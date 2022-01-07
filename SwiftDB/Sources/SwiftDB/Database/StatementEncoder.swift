import Foundation


/// Encodes a value by binding its properties to named parameters of a query
struct StatementEncoder {
    
    func encode<T: Encodable>(_ value: T, into statement: Statement) throws {
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
        return NotImplementedEncoder(feature: "providing arrays of parameter values to a statement (currently you must use structs or dictionaries to bind named parameters instead)").unkeyedContainer()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        NotImplementedEncoder(feature: "providing single parameter values to a statement (currently you must use structs or dictionaries to bind named parameters instead)").singleValueContainer()
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
        try bind(.int(value ? 1 : 0), to: key)
    }
    
    mutating func encode(_ value: String, forKey key: Key) throws {
        try bind(.text(value), to: key)
    }
    
    mutating func encode(_ value: Double, forKey key: Key) throws {
        try bind(.double(value), to: key)
    }
    
    mutating func encode(_ value: Float, forKey key: Key) throws {
        try bind(.double(Double(value)), to: key)
    }
    
    mutating func encode(_ value: Int, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: Int8, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: Int16, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: Int64, forKey key: Key) throws {
        try bind(.int(value), to: key)
    }
    
    mutating func encode(_ value: UInt, forKey key: Key) throws {
        // allow 64 bit unsigned integer to overflow - the decoder will reverse it
        try bind(.int(Int64(truncatingIfNeeded: value)), to: key)
    }
    
    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try bind(.int(Int64(value)), to: key)
    }
    
    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        // allow 64 bit unsigned integer to overflow - the decoder will reverse it
        try bind(.int(Int64(truncatingIfNeeded: value)), to: key)
    }
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // IMPORTANT: any special cases here need matching special cases
        // in StatementDecoder.decode<T>(_:forKey:)
        if let value = value as? _OptionalProtocol, value.isNil {
            try encodeNil(forKey: key)
        }
        else if let value = value as? Data {
            try bind(.blob(value), to: key)
        }
        else if let value = value as? String {
            try bind(.text(value), to: key)
        }
        else if let value = value as? Date {
            let dateString = iso8601Formatter.string(from: value)
            try bind(.text(dateString), to: key)
        }
        else {
            let encoded = try JSONColumn.encode(value)
            try bind(.text(encoded), to: key)
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
    
    func bind(_ value: Parameter, to key: Key) throws {
        try statement.bind(value, to: ":\(key.stringValue)")
    }
    
}

/// An `Encoder` that throws `SwiftDBError.notImplemented` for every method
///
/// This is required because various methods on the `Encoder` protocol are not marked `throws` so it
/// is necessary to return one of these and throw the error when it is used
private struct NotImplementedEncoder: Encoder {
    let feature: String
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey : Any]()
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(KeyedContainer(feature: feature))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContainer(feature: feature)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer(feature: feature)
    }
    
    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let feature: String
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey : Any]()
        
        mutating func encodeNil(forKey key: Key) throws {
            try error()
        }
        
        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            try error()
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            return NotImplementedEncoder(feature: feature).container(keyedBy: keyType)
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            return NotImplementedEncoder(feature: feature).unkeyedContainer()
        }
        
        mutating func superEncoder() -> Encoder {
            return NotImplementedEncoder(feature: feature)
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            return NotImplementedEncoder(feature: feature)
        }
        
        func error() throws -> Never {
            throw SwiftDBError.notImplemented(feature: feature)
        }
    }


    private struct UnkeyedContainer: UnkeyedEncodingContainer {
        let feature: String
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey : Any]()
        
        let count: Int = 0
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            throw SwiftDBError.notImplemented(feature: feature)
        }
        
        mutating func encodeNil() throws {
            throw SwiftDBError.notImplemented(feature: feature)
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
            return NotImplementedEncoder(feature: feature).container(keyedBy: keyType)
        }
        
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            return NotImplementedEncoder(feature: feature).unkeyedContainer()
        }
        
        mutating func superEncoder() -> Encoder {
            return NotImplementedEncoder(feature: feature)
        }
        
    }


    private struct SingleValueContainer: SingleValueEncodingContainer {
        let feature: String
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey : Any]()
        
        let count: Int = 0
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            throw SwiftDBError.notImplemented(feature: feature)
        }
        
        mutating func encodeNil() throws {
            throw SwiftDBError.notImplemented(feature: feature)
        }
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
