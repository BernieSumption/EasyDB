import Foundation
import SQLite3

class Connection {
    private let database: Database
    private let connectionPointer: OpaquePointer
    private var registeredCollationNames = Set<String>()
    private var collationFunctions = [CollationFunction]()

    init(_ database: Database) throws {
        self.database = database
        var connectionPointer: OpaquePointer?
        try checkOK(sqlite3_open(database.path, &connectionPointer), sql: nil, db: nil)
        self.connectionPointer = try checkPointer(connectionPointer, from: "sqlite3_open")
        registerCollation(.binary)
        registerCollation(.string)
        registerCollation(.caseInsensitive)
        registerCollation(.localized)
        registerCollation(.localizedCaseInsensitive)
    }

    /// Compile and execute an SQL query, decoding the results into an instance of `T`
    func execute<T: Decodable>(_ resultType: T.Type, sql: String, parameters: [DatabaseValue] = []) throws -> T {
        return try database.inAccessQueue {
            let statement = try notThreadSafe_prepare(sql: sql)
            defer { statement.reset() }
            try statement.bind(parameters)
            return try StatementDecoder.decode(resultType, from: statement)
        }
    }

    /// Compile and execute an SQL query that returns no results
    func execute(sql: String, parameters: [DatabaseValue] = []) throws {
        return try database.inAccessQueue {
            let statement = try notThreadSafe_prepare(sql: sql)
            defer { statement.reset() }
            try statement.bind(parameters)
            _ = try statement.step()
        }
    }

    /// Compile and execute an SQL query that returns no results, getting named parameters from the provided struct or dictionary
    func execute<P: Codable>(sql: String, namedParameters: P) throws {
        return try database.inAccessQueue {
            let statement = try notThreadSafe_prepare(sql: sql)
            defer { statement.reset() }
            try StatementEncoder.encode(namedParameters, into: statement)
            _ = try statement.step()
        }
    }

    func notThreadSafe_prepare(sql: String) throws -> Statement {
        return try Statement(connectionPointer, sql, logSQL: database.logSQL)
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
