import Foundation
import SQLite3

class Connection {
    private let database: EasyDB
    private let connectionPointer: OpaquePointer
    private var registeredCollationNames = Set<String>()
    private var registeredCollections = Set<ObjectIdentifier>()
    private var collationFunctions = [CollationFunction]()

    public let write: Bool

    init(_ database: EasyDB, write: Bool = true) throws {
        self.database = database
        self.write = write
        var connectionPointer: OpaquePointer?
        let flags = SQLITE_OPEN_NOMUTEX
            | (write
               ? SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
               : SQLITE_OPEN_READONLY)
        try checkOK(
            sqlite3_open_v2(database.path, &connectionPointer, flags, nil),
            sql: nil,
            db: nil)
        self.connectionPointer = try checkPointer(connectionPointer, from: "sqlite3_open")
        registerCollation(.binary)
        registerCollation(.string)
        registerCollation(.caseInsensitive)
        registerCollation(.localized)
        registerCollation(.localizedCaseInsensitive)

    }

    deinit {
        let result = sqlite3_close(connectionPointer)
        if result != SQLITE_OK {
            sqlite3_close_v2(connectionPointer)
            assert(false, "Failed to close connection, sqlite3_close returned \(result) - this is a bug in EasyDB that should be reported")
        }
    }

    /// Compile and execute an SQL query, decoding the results into an instance of `T`
    func execute<T: Decodable>(_ resultType: T.Type, sql: String, parameters: [DatabaseValue] = []) throws -> T {
        let statement = try prepare(sql: sql)
        defer { statement.reset() }
        try statement.bind(parameters)
        return try StatementDecoder.decode(resultType, from: statement)
    }

    /// Compile and execute an SQL query that returns no results
    func execute(sql: String, parameters: [DatabaseValue] = []) throws {
        let statement = try prepare(sql: sql)
        defer { statement.reset() }
        try statement.bind(parameters)
        _ = try statement.step()
    }

    /// Compile and execute an SQL query that returns no results, getting named parameters from the provided struct or dictionary
    func execute<P: Codable>(sql: String, namedParameters: P) throws {
        return try database.withConnection(write: true) { _ in
            let statement = try prepare(sql: sql)
            defer { statement.reset() }
            try StatementEncoder.encode(namedParameters, into: statement)
            _ = try statement.step()
        }
    }

    func prepare(sql: String) throws -> Statement {
        return try Statement(connectionPointer, sql, logSQL: database.logSQL)
    }

    func registerCollection<T>(_ collection: Collection<T>) {
        let id = ObjectIdentifier(collection)
        guard !registeredCollections.contains(id) else {
            return
        }
        registeredCollections.insert(id)

        for collation in collection.allDefaultCollations {
            registerCollation(collation)
        }
    }

    func registerCollation(_ collation: Collation) {
        guard !registeredCollationNames.contains(collation.normalizedName) else {
            return
        }
        registeredCollationNames.insert(collation.normalizedName)

        guard let compare = collation.compare else {
            return
        }

        let function = CollationFunction(compare)
        collationFunctions.append(function) // keep a reference to the function so that ti is not freed
        let functionPointer = Unmanaged.passUnretained(function).toOpaque()
        let code = sqlite3_create_collation_v2(
            connectionPointer,
            collation.name,
            SQLITE_UTF8,
            functionPointer,
            { (arg, size1, data1, size2, data2) -> Int32 in
                let function = Unmanaged<CollationFunction>.fromOpaque(arg!).takeUnretainedValue()
                return Int32(function.compare(size1, data1, size2, data2).rawValue)
            }, nil)
        guard code == SQLITE_OK else {
            fatalError("call to sqlite3_create_collation_v2 failed with code \(code)")
        }
    }
}

/// Wrapper for a collation function - required because we need a reference type for `Unmanaged.passRetained(_:)`
class CollationFunction {
    let compare: SQLiteCustomCollationFunction

    init(_ compare: @escaping SQLiteCustomCollationFunction) {
        self.compare = compare
    }
}

internal func checkOK(_ code: CInt, sql: String?, db: OpaquePointer?) throws {
    let resultCode = try ResultCode(code)
    var message: String?
    if let db = db {
        message = String(cString: sqlite3_errmsg(db))
    }
    if resultCode != .OK {
        throw ConnectionError(resultCode: resultCode, message: message, sql: sql)
    }
}

internal func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws -> OpaquePointer
{
    guard let pointer = pointer else {
        throw EasyDBError.unexpected(message: "expected \(functionName) to set a pointer")
    }
    return pointer
}
