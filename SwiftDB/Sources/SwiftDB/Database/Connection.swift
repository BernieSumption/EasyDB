import Foundation
import CSQLite


private let logErrors = true


private var lastMessage: String?
private func logCallback(_: UnsafeMutableRawPointer?, _ code: Int32, _ message: UnsafePointer<CChar>?) -> Void {
    guard let message = message.map(String.init) else { return }
    lastMessage = message
    // TODO: move logging to options API
    if logErrors {
        print("\(ResultCode.nameForCode(code)) / \(message)")
    }
}

class Connection {
    internal let db: OpaquePointer

    init(path: String) throws {
        registerErrorLogCallback(logCallback)
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

struct ConnectionError: Error, CustomStringConvertible {
    let resultCode: ResultCode
    let message: String?
    let sql: String?
    
    var description: String {
        "\(resultCode) (SQLite message: \(message ?? "none"); Query: \(sql ?? "none")"
    }
}


internal func checkOK(_ code: @autoclosure () -> CInt, sql: String?) throws {
    lastMessage = nil
    let resultCode = try ResultCode(code())
    if resultCode != .OK {
        throw ConnectionError(resultCode: resultCode, message: lastMessage, sql: sql)
    }
}

internal func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws -> OpaquePointer
{
    guard let pointer = pointer else {
        throw SwiftDBError.unexpected(message: "expected \(functionName) to set a pointer")
    }
    return pointer
}
