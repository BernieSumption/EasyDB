import SQLite3
import Foundation

class Connection {
    private let db: OpaquePointer
    
    init(path: String) throws {
        var db: OpaquePointer?
        try checkOK(sqlite3_open(path, &db))
        self.db = try checkPointer(db, from: "sqlite3_open")
    }
    
    func prepare(sql: String) throws -> PreparedStatement {
        return try PreparedStatement(db, sql)
    }
    
    class PreparedStatement {
        private let statement: OpaquePointer
        private var hasExecuted = false
        
        init(_ db: OpaquePointer, _ sql: String) throws {
            var statement: OpaquePointer?
            try checkOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
            self.statement = try checkPointer(statement, from: "sqlite3_prepare_v2")
        }
        
        func execute(arguments: [Parameter] = []) {
            if hasExecuted {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
            }
            
            var index: Int32 = 1
            for argument in arguments {
                switch argument {
                case .double(let double):
                    sqlite3_bind_double(statement, index, double)
                case .int(let int):
                    sqlite3_bind_int(statement, index, int)
                case .int64(let int64):
                    sqlite3_bind_int64(statement, index, int64)
                case .null:
                    sqlite3_bind_null(statement, index)
                case .text(let string):
                    sqlite3_bind_text(statement, index, string, -1, nil)
                }
                index += 1
            }
            
            hasExecuted = true
        }
        
        deinit {
            sqlite3_finalize(statement)
        }
    }
    
    enum Parameter {
        case double(Double)
        case int(Int32)
        case int64(Int64)
        case null
        case text(String)
    }

}


func checkOK(_ code: CInt) throws {
    if code != SQLITE_OK {
        guard let resultCode = ResultCode(rawValue: code) else {
            throw SwiftDBError.unexpected("SQLite returned invalid result code \(code)")
        }
        throw resultCode
    }
}

func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws -> OpaquePointer {
    guard let pointer = pointer else {
        throw SwiftDBError.unexpected("expected \(functionName) to set a pointer")
    }
    return pointer
}
