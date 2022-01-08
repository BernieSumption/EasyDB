import Foundation
import CSQLite

class Connection {
    internal let db: OpaquePointer

    init(path: String) throws {
        if !errorCallbackRegistered {
            errorCallbackRegistered = true
            registerErrorLogCallback(errorLogCallback)
        }
        var db: OpaquePointer?
        try checkOK(sqlite3_open(path, &db), sql: nil)
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


private var errorCallbackRegistered = false
private var lastMessage: String?
private func errorLogCallback(
    _: UnsafeMutableRawPointer?,
    _ code: Int32,
    _ cMessage: UnsafePointer<CChar>?
) -> Void {
    guard let cMessage = cMessage else { return }
    let message = String(cString: cMessage)
    lastMessage = message
}

internal func checkOK(_ code: @autoclosure () -> CInt, sql: String?) throws {
    lastMessage = nil
    let resultCode = try ResultCode(code())
    if resultCode != .OK {
        throw ConnectionError(resultCode: resultCode, lastMessage: lastMessage, sql: sql)
    }
}

internal func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws -> OpaquePointer
{
    guard let pointer = pointer else {
        throw SwiftDBError.unexpected(message: "expected \(functionName) to set a pointer")
    }
    return pointer
}
