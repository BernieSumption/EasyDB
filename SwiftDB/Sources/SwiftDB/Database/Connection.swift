import Foundation
import SQLite3
import os

let swiftDBLog = Logger.init(subsystem: "SwiftDB", category: "sql")

class Connection {
    let db: OpaquePointer
    let logSQL: Bool

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
