
/// An `Encoder` that throws an error for every method
///
/// This is required because various methods on the `Encoder` protocol are not marked `throws` so if
/// they are not supported it is necessary to return one of these and throw the error when it is used
struct NotImplementedEncoder: Encoder {
    let error: Error
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey: Any]()
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(KeyedContainer(error: error))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContainer(error: error)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer(error: error)
    }
    
    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let error: Error
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()
        
        mutating func encodeNil(forKey key: Key) throws {
            throw error
        }
        
        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            throw error
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            return NotImplementedEncoder(error: error).container(keyedBy: keyType)
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            return NotImplementedEncoder(error: error).unkeyedContainer()
        }
        
        mutating func superEncoder() -> Encoder {
            return NotImplementedEncoder(error: error)
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            return NotImplementedEncoder(error: error)
        }
    }

    private struct UnkeyedContainer: UnkeyedEncodingContainer {
        let error: Error
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()
        
        let count: Int = 0
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            throw error
        }
        
        mutating func encodeNil() throws {
            throw error
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
            return NotImplementedEncoder(error: error).container(keyedBy: keyType)
        }
        
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            return NotImplementedEncoder(error: error).unkeyedContainer()
        }
        
        mutating func superEncoder() -> Encoder {
            return NotImplementedEncoder(error: error)
        }
        
    }

    private struct SingleValueContainer: SingleValueEncodingContainer {
        let error: Error
        let codingPath = [CodingKey]()
        let userInfo = [CodingUserInfoKey: Any]()
        
        let count: Int = 0
        
        mutating func encode<T: Encodable>(_ value: T) throws {
            throw error
        }
        
        mutating func encodeNil() throws {
            throw error
        }
    }
}
