import Foundation
import SQLite3

class Connection {
    private let db: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        try checkOK(sqlite3_open(path, &db))
        self.db = try checkPointer(db, from: "sqlite3_open")
    }

    func prepare(sql: String) throws -> Statement {
        return try Statement(db, sql)
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

