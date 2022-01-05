import Foundation

struct StatementDecoder {
    
    func decode<T: Decodable>(_ type: T.Type, from statement: Statement) throws -> T {
        let _ = try statement.step()
        let decoder = StatementDecoderImpl(statement, codingPath: [])
        if type == Data.self || type == Date.self  {
            return try decoder.singleValueContainer().decode(type)
        }
        return try T(from: decoder)
    }
}

struct StatementDecoderImpl: Decoder {
    private let statement: Statement
    let codingPath: [CodingKey]
    let userInfo = [CodingUserInfoKey : Any]()
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(StatementRowKeyedContainer(statement, codingPath: codingPath))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        Next up: if were already in a row (codingKeys.count > 0) return a StatementRowUnkeyedContainer
        return StatementRowsContainer(statement, codingPath: [])
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return StatementRowToScalarContainer(statement, codingPath: codingPath)
    }
}

private struct StatementRowKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
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
            throw SwiftDBError.decodingError(
                message: "number value \(value64) doesn't fit exactly into a \(T.self)",
                codingPath: codingPath)
        }
        return value
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        if type == Data.self {
            return try statement.readBlob(column: key.stringValue) as! T
        }
        let string = try decode(String.self, forKey: key)
        if type == String.self {
            return string as! T
        }
        if type == Date.self {
            return try parseISODate(string, codingPath: codingPath) as! T
        }
        return try JSONColumn.decode(type, from: string)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        throw SwiftDBError.decodingError(
            message: "Decodable types that use KeyedDecodingContainer.nestedContainer are not supported",
            codingPath: codingPath)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw SwiftDBError.decodingError(
            message: "Decodable types that use KeyedDecodingContainer.nestedUnkeyedContainer are not supported",
            codingPath: codingPath)
    }
    
    func superDecoder() throws -> Decoder {
        throw SwiftDBError.decodingError(
            message: "Decodable types that use KeyedDecodingContainer.superDecoder (usually class types) are not supported",
            codingPath: codingPath)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        throw SwiftDBError.decodingError(
            message: "Decodable types that use KeyedDecodingContainer.superDecoder(forKey:) (usually class types) are not supported",
            codingPath: codingPath)
    }
    
}

struct StatementRowToScalarContainer: SingleValueDecodingContainer {
    private let statement: Statement
    
    let codingPath: [CodingKey]
    
    init(_ statement: Statement, codingPath: [CodingKey]) {
        self.statement = statement
        self.codingPath = codingPath
    }
    
    func decodeNil() -> Bool {
        guard let isNull = try? statement.readNull(column: 0) else {
            return false
        }
        return isNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        try statement.readInt(column: 0) != 0
    }
    
    func decode(_ type: String.Type) throws -> String {
        try statement.readText(column: 0)
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        return try statement.readDouble(column: 0)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return Float(try statement.readDouble(column: 0))
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
        return try statement.readInt(column: 0)
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
        let value64 = try statement.readInt(column: 0)
        return UInt64(truncatingIfNeeded: value64)
    }
    
    private func decodeInteger<T: FixedWidthInteger>() throws -> T {
        let value64 = try statement.readInt(column: 0)
        guard let value: T = T(exactly: value64) else {
            throw SwiftDBError.decodingError(
                message: "number value \(value64) doesn't fit into a \(T.self)",
                codingPath: codingPath)
        }
        return value
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if type == Data.self {
            return try statement.readBlob(column: 0) as! T
        }
        let string = try decode(String.self)
        if type == Date.self {
            return try parseISODate(string, codingPath: codingPath) as! T
        }
        return try JSONDecoder().decode(type, from: Data(string.utf8))
    }
}

var _id = 0

/// Decodes multiple rows in a statement
class StatementRowsContainer: UnkeyedDecodingContainer {
    private let statement: Statement
    private var needsStep = false
    private var errorFromIsAtEnd: Error? = nil
    private let id: Int = {
        let thisId = _id
        _id += 1
        return thisId
    }()
    
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
            // the API won't let us throw an error so we save it and throw it from the decode method when called
            errorFromIsAtEnd = error
            return false
        }
        return !statement.hasRow
    }
    
    func decodeNil() throws -> Bool {
        return false
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
        return try nextDecoder()
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T(from: nextDecoder())
    }

    private func nextDecoder() throws -> StatementDecoderImpl {
        if let error = errorFromIsAtEnd {
            throw error
        }
        try stepIfRequired()
        needsStep = true
        let key = StatementKey(currentIndex)
        currentIndex += 1
        return StatementDecoderImpl(statement, codingPath: self.codingPath + [key])
    }
    
    private func stepIfRequired() throws {
        if needsStep {
            print("Stepping \(id)")
            var _ = try statement.step()
            needsStep = false
        }
    }
}


private var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

private func parseISODate(_ string: String, codingPath: [CodingKey]) throws -> Date {
    guard let date = iso8601Formatter.date(from: string) else {
        throw SwiftDBError.decodingError(
            message: "Expected an ISO 8601 date string, got \"\(string)\"",
            codingPath: codingPath
        )
    }
    return date
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
