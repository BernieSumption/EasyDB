import Foundation
import SQLite3

class Connection {
    private let db: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        func log() {
            
        }
        try checkOK(sqlite3_open(path, &db))
        self.db = try checkPointer(db, from: "sqlite3_open")
    }

    /// Compile a prepared statement
    func prepare(sql: String) throws -> Statement {
        return try Statement(db, sql)
    }
    
    /// Compile and execute an SQL query, decoding the results into an instance of `T`
    func execute<T: Decodable>(_ resultType: T.Type, sql: String, parameters: [Parameter] = []) throws -> T {
        let statement = try prepare(sql: sql)
        try statement.bind(parameters)
        return try StatementDecoder().decode(resultType, from: statement)
    }
    
    /// Compile and execute an SQL query that returns no results
    func execute(sql: String, parameters: [Parameter] = []) throws {
        let statement = try prepare(sql: sql)
        try statement.bind(parameters)
        let _ = try statement.step()
    }
}

internal func checkOK(_ code: CInt) throws {
    let resultCode = try ResultCode(code)
    if resultCode != .OK {
        throw resultCode
    }
}

internal func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws
    -> OpaquePointer
{
    guard let pointer = pointer else {
        throw SwiftDBError.unexpected(message: "expected \(functionName) to set a pointer")
    }
    return pointer
}

