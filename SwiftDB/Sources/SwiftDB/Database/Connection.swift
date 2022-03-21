import Foundation
import SQLite3
import os

let swiftDBLog = Logger.init(subsystem: "SwiftDB", category: "sql")

class Connection {
    let db: OpaquePointer
    let logSQL: Bool
    var registeredCollationNames = Set<String>()

    init(path: String, logSQL: Bool = false) throws {
        self.logSQL = logSQL
        var db: OpaquePointer?
        try checkOK(sqlite3_open(path, &db), sql: nil, db: nil)
        self.db = try checkPointer(db, from: "sqlite3_open")
    }

    /// Compile a prepared statement
    func prepare(sql: String) throws -> Statement {
        return try Statement(db, sql, log: logSQL)
    }
    
    /// Compile and execute an SQL query, decoding the results into an instance of `T`
    func execute<T: Decodable>(_ resultType: T.Type, sql: String, parameters: [DatabaseValue] = []) throws -> T {
        let statement = try prepare(sql: sql)
        try statement.bind(parameters)
        return try StatementDecoder.decode(resultType, from: statement)
    }
    
    /// Compile and execute an SQL query that returns no results
    func execute(sql: String, parameters: [DatabaseValue] = []) throws {
        let statement = try prepare(sql: sql)
        try statement.bind(parameters)
        let _ = try statement.step()
    }
    
    public func registerCollation(_ collation: Collation) {
        return
        guard !registeredCollationNames.contains(collation.normalizedName) else {
            return
        }
        registeredCollationNames.insert(collation.normalizedName)
        
        guard let compare = collation.compare else {
            return
        }
        
        let function = CollationFunctionWrapper(compare)
        let functionPointer = Unmanaged.passRetained(function).toOpaque()
        let code = sqlite3_create_collation_v2(
            db,
            collation.name,
            SQLITE_UTF8,
            functionPointer,
            { (arg, size1, data1, size2, data2) -> Int32 in
                let function = Unmanaged<CollationFunctionWrapper>.fromOpaque(arg!).takeUnretainedValue()
                return Int32(function.compare(size1, data1, size2, data2).rawValue)
            }, nil)
        guard code == SQLITE_OK else {
            fatalError("call to sqlite3_create_collation_v2 failed with code \(code)")
        }
    }
}

/// Wrapper for a collation function - required because we need a reference type for `Unmanaged.passRetained(_:)`
class CollationFunctionWrapper {
    let compare: SQLiteCustomCollationFunction
    
    init(_ compare: @escaping SQLiteCustomCollationFunction) {
        self.compare = compare
    }
}

internal func checkOK(_ code: @autoclosure () -> CInt, sql: String?, db: OpaquePointer?) throws {
    let resultCode = try ResultCode(code())
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
        throw SwiftDBError.unexpected(message: "expected \(functionName) to set a pointer")
    }
    return pointer
}
