import Foundation

/// Decodes a statement's results into a `Codable` type, making an effort to do something pretty
/// sensible for any codable type.
struct StatementDecoder {
    func decode<T: Decodable>(_ type: T.Type, from statement: Statement, maxRows: Int? = nil) throws -> T {
        let _ = try statement.step()
        let decoder = StatementDecoderImpl(statement, maxRows: maxRows)
        if type == Data.self || type == Date.self  {
            return try decoder.singleValueContainer().decode(type)
        }
        return try T(from: decoder)
    }
}

// MARK: Decoders

/// The top-level decoder, decoding the result(s) of an SQL query
private struct StatementDecoderImpl: Decoder {
    private let statement: Statement
    private let maxRows: Int?
    let codingPath = [CodingKey]() // always top level so empty coding path
    let userInfo = [CodingUserInfoKey : Any]()
    
    init(_ statement: Statement, maxRows: Int? = nil) {
        self.statement = statement
        self.maxRows = maxRows
    }
    
    /// Decode the first row of results into a struct or dictionary
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(SingleRowKeyedContainer(statement, codingPath: codingPath))
    }
    
    /// Decode all rows in the response into an array, each row becoming an element in the array
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return ManyRowsUnkeyedContainer(statement, codingPath: [], maxRows: maxRows)
    }
    
    /// Decode the first column of the first row into a scalar value
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleRowSingleValueContainer(statement, column: 0, codingPath: codingPath)
    }
}

/// The second-level decoder, decoding a row within the results
private struct SingleRowDecoderImpl: Decoder {
    private let statement: Statement
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey : Any]()
    
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
        return SingleRowUnkeyedContainer(statement, codingPath: [])
    }
    
    /// Decode the first column into a scalar value
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleRowSingleValueContainer(statement, column: 0, codingPath: codingPath)
    }
}

/// The third-level decoder, decoding a column value within a row within the results
private struct SingleRowSingleColumnDecoderImpl: Decoder {
    private let statement: Statement
    private let column: Int
    
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey : Any]()
    
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
        return SingleRowSingleValueContainer(statement, column: column, codingPath: codingPath)
    }
}

// MARK: Containers

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
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try statement.readInt(column: key.stringValue) != 0
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try statement.readText(column: key.stringValue)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try statement.readDouble(column: key.stringValue)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return Float(try statement.readDouble(column: key.stringValue))
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try statement.readInt(column: key.stringValue)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return UInt(try decode(UInt64.self, forKey: key))
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeInteger(forKey: key)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        // for UInt64 we let the value overflow, because that's the only way of storing a UInt64 in sqlite
        let value64 = try statement.readInt(column: key.stringValue)
        return UInt64(truncatingIfNeeded: value64)
    }
    
    private func decodeInteger<T: FixedWidthInteger>(forKey key: Key) throws -> T {
        let value64 = try statement.readInt(column: key.stringValue)
        guard let value: T = T(exactly: value64) else {
            throw SwiftDBError.codingError(
                message: "number value \(value64) doesn't fit exactly into a \(T.self)",
                codingPath: codingPath)
        }
        return value
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // IMPORTANT: any special cases here need matching special cases
        // in StatementEncoder.encode<T>(_:forKey:) and in other decoding methods
        // in this file
        if let type = type as? _OptionalProtocol.Type {
            if try statement.readNull(column: key.stringValue) {
                return type.nilValue as! T
            }
        }
        if type == Data.self {
            return try statement.readBlob(column: key.stringValue) as! T
        }
        let string = try decode(String.self, forKey: key)
        return try decodeStringHelper(type, from: string, codingPath: codingPath)
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

/// Decodes one row of the results into a single value using the first column of the row
private struct SingleRowSingleValueContainer: SingleValueDecodingContainer {
    private let statement: Statement
    private let column: Int
    
    let codingPath: [CodingKey]
    
    init(_ statement: Statement, column: Int, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
        self.column = column
    }
    
    func decodeNil() -> Bool {
        guard let isNull = try? statement.readNull(column: column) else {
            return false
        }
        return isNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        try statement.readInt(column: column) != 0
    }
    
    func decode(_ type: String.Type) throws -> String {
        try statement.readText(column: column)
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        return try statement.readDouble(column: column)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return Float(try statement.readDouble(column: column))
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        return try decodeInteger()
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        return try decodeInteger()
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        return try decodeInteger()
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        return try decodeInteger()
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        return try statement.readInt(column: column)
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        return try decodeInteger()
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try decodeInteger()
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try decodeInteger()
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try decodeInteger()
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let value64 = try statement.readInt(column: column)
        return UInt64(truncatingIfNeeded: value64)
    }
    
    private func decodeInteger<T: FixedWidthInteger>() throws -> T {
        let value64 = try statement.readInt(column: column)
        guard let value: T = T(exactly: value64) else {
            throw SwiftDBError.codingError(
                message: "number value \(value64) doesn't fit into a \(T.self)",
                codingPath: codingPath)
        }
        return value
    }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T  {
        // IMPORTANT: any special cases here need matching special cases
        // in StatementEncoder.encode<T>(_:forKey:) and in other decoding methods
        // in this file
        if let type = type as? _OptionalProtocol.Type {
            if try statement.readNull(column: column) {
                return type.nilValue as! T
            }
        }
        if type == Data.self {
            return try statement.readBlob(column: column) as! T
        }
        let string = try decode(String.self)
        return try decodeStringHelper(type, from: string, codingPath: codingPath)
    }
}

/// Decodes all rows in the response into an array, each row becoming an element in the array
private class ManyRowsUnkeyedContainer: UnkeyedDecodingContainer {
    private let statement: Statement
    private let maxRows: Int?
    private var needsStep = false
    private var errorFromIsAtEnd: Error? = nil
    
    let codingPath: [CodingKey]
    
    init(_ statement: Statement, codingPath: [CodingKey], maxRows: Int? = nil) {
        self.statement = statement
        self.codingPath = codingPath
        self.maxRows = maxRows
    }

    let count: Int? = nil // nil = count unknown in advance
    private(set) var currentIndex: Int = 0
    
    var isAtEnd: Bool {
        if let maxRows = maxRows, currentIndex >= maxRows {
            return true
        }
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

private func decodeStringHelper<T: Decodable>(
    _ type: T.Type,
    from string: String,
    codingPath: [CodingKey]
) throws -> T  {
    // IMPORTANT: any special cases here need matching special cases
    // in StatementEncoder.encode<T>(_:forKey:) and in other decoding methods
    // in this file
    if type == String.self {
        return string as! T
    }
    if type == Date.self {
        return try parseISODate(string, codingPath: codingPath) as! T
    }
    return try JSONColumn.decode(type, from: string)
}

internal var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

private func parseISODate(_ string: String, codingPath: [CodingKey]) throws -> Date {
    guard let date = iso8601Formatter.date(from: string) else {
        throw SwiftDBError.codingError(
            message: "Expected an ISO 8601 date string, got \"\(string)\"",
            codingPath: codingPath
        )
    }
    return date
}

private protocol _OptionalProtocol {
  static var nilValue: Self { get }
}

extension Optional : _OptionalProtocol {
    static var nilValue: Self { return nil }
}
