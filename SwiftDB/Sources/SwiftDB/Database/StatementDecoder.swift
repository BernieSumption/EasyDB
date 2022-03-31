import Foundation

/// Decodes a statement's results into a `Codable` type, making an effort to do something pretty
/// sensible for any codable type. See TODO: URL for query decoding
struct StatementDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from statement: Statement) throws -> T {
        _ = try statement.step()
        let decoder = StatementDecoderImpl(statement)
        if type is DatabaseValueConvertible.Type  {
            return try decoder.singleValueContainer().decode(type)
        }
        return try T(from: decoder)
    }
}

/// The top-level decoder, decoding the result(s) of an SQL query
private struct StatementDecoderImpl: Decoder {
    private let statement: Statement
    let codingPath = [CodingKey]() // always top level so empty coding path
    let userInfo = [CodingUserInfoKey: Any]()
    
    init(_ statement: Statement) {
        self.statement = statement
    }
    
    /// Decode the first row of results into a struct or dictionary
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(SingleRowKeyedContainer(statement, codingPath: codingPath))
    }
    
    /// Decode all rows in the response into an array, each row becoming an element in the array
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return ManyRowsUnkeyedContainer(statement, codingPath: [])
    }
    
    /// Decode the first column of the first row into a single value
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        let value = try statement.read(column: 0)
        return try DatabaseValueDecoder.singleValueContainer(value, codingPath: codingPath)
    }
}

/// The second-level decoder, decoding a row within the results
private struct SingleRowDecoderImpl: Decoder {
    private let statement: Statement
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey: Any]()
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
    }
    
    /// Decode the row into a struct or dictionary
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(SingleRowKeyedContainer(statement, codingPath: codingPath))
    }
    
    /// Decode the row into an array, each column becoming an element in the array
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return SingleRowUnkeyedContainer(statement, codingPath: codingPath)
    }
    
    /// Decode the first column into a scalar value
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        let value = try statement.read(column: 0)
        return try DatabaseValueDecoder.singleValueContainer(value, codingPath: codingPath)
    }
}

/// The third-level decoder, decoding a column value within a row within the results
private struct SingleRowSingleColumnDecoderImpl: Decoder {
    private let statement: Statement
    private let column: Int
    
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey: Any]()
    
    init(_ statement: Statement, column: Int, codingPath: [CodingKey]) {
        self.statement = statement
        self.column = column
        self.codingPath = codingPath
    }
    
    /// Treat the value as a JSON-encoded string and decode it into a struct or dictionary
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw SwiftDBError.notImplemented(feature: "decoding 2D arrays of objects e.g. [[MyStruct]].self")
    }
    
    /// Treat the value as a JSON-encoded string and decode it into an array
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw SwiftDBError.notImplemented(feature: "decoding 3D array e.g. [[[T]]].self")
    }
    
    /// Decode the value into a scalar value
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        let value = try statement.read(column: column)
        return try DatabaseValueDecoder.singleValueContainer(value, codingPath: codingPath)
    }
}

/// Decodes one row of the results into a struct or dictionary using column names for keys
private struct SingleRowKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let statement: Statement
    
    let codingPath: [CodingKey]
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
    }
    
    var allKeys: [Key] {
        statement.columnNames.compactMap { name in
            Key(stringValue: name)
        }
    }
    
    func contains(_ key: Key) -> Bool {
        return statement.hasColumn(key.stringValue)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return try statement.readNull(column: key.stringValue)
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let value = try statement.read(column: key.stringValue)
        return try DatabaseValueDecoder.decode(type, from: value)
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw SwiftDBError.codingError(
            message: "Decodable types that use KeyedDecodingContainer.nestedContainer are not supported",
            codingPath: codingPath)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw SwiftDBError.codingError(
            message: "Decodable types that use KeyedDecodingContainer.nestedUnkeyedContainer are not supported",
            codingPath: codingPath)
    }
    
    func superDecoder() throws -> Decoder {
        throw SwiftDBError.codingError(
            message: "Decodable types that use KeyedDecodingContainer.superDecoder (usually class types) are not supported",
            codingPath: codingPath)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        throw SwiftDBError.codingError(
            message: "Decodable types that use KeyedDecodingContainer.superDecoder(forKey:) (usually class types) are not supported",
            codingPath: codingPath)
    }
}

/// Decodes all rows in the response into an array, each row becoming an element in the array
private class ManyRowsUnkeyedContainer: UnkeyedDecodingContainer {
    private let statement: Statement
    private var needsStep = false
    private var errorFromIsAtEnd: Error?
    
    let codingPath: [CodingKey]
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
    }

    let count: Int? = nil // nil = count unknown in advance
    private(set) var currentIndex: Int = 0
    
    var isAtEnd: Bool {
        do {
            try stepIfRequired()
        } catch {
            // the API won't let us throw an error so we save it to throw later
            errorFromIsAtEnd = error
            return false
        }
        return !statement.hasRow
    }
    
    func decodeNil() throws -> Bool {
        return false // a row can't be null
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        return try nextDecoder().container(keyedBy: type)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try nextDecoder().unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        throw SwiftDBError.codingError(
            message: "Decodable types that use UnkeyedDecodingContainer.superDecoder (usually class types) are not supported",
            codingPath: codingPath)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T(from: nextDecoder())
    }

    private func nextDecoder() throws -> SingleRowDecoderImpl {
        if let error = errorFromIsAtEnd {
            throw error
        }
        try stepIfRequired()
        needsStep = true
        let key = StatementKey(currentIndex)
        currentIndex += 1
        return SingleRowDecoderImpl(statement, codingPath: self.codingPath + [key])
    }
    
    private func stepIfRequired() throws {
        if needsStep {
            var _ = try statement.step()
            needsStep = false
        }
    }
}

/// Decodes a single row into an array, each column becoming an element in the array
private class SingleRowUnkeyedContainer: UnkeyedDecodingContainer {
    private let statement: Statement
    
    let codingPath: [CodingKey]
    let _count: Int
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
        self._count = statement.columnCount
    }

    private(set) var currentIndex: Int = 0
    
    var isAtEnd: Bool {
        currentIndex >= _count
    }
    
    var count: Int? { _count }
    
    func decodeNil() throws -> Bool {
        return try statement.readNull(column: currentIndex)
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        return try nextDecoder().container(keyedBy: type)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try nextDecoder().unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        throw SwiftDBError.codingError(
            message: "Decodable types that use UnkeyedDecodingContainer.superDecoder (usually class types) are not supported",
            codingPath: codingPath)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T(from: nextDecoder())
    }

    private func nextDecoder() throws -> SingleRowSingleColumnDecoderImpl {
        let index = currentIndex
        currentIndex += 1
        return SingleRowSingleColumnDecoderImpl(
            statement, column: index,
            codingPath: self.codingPath + [StatementKey(index)])
    }
}

private struct StatementKey: CodingKey {
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
