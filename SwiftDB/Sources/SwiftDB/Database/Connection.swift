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
        private var hasRow = false
        private var columnNames = [String: Int32]()
        private var hasColumnNames = false
        
        init(_ db: OpaquePointer, _ sql: String) throws {
            var statement: OpaquePointer?
            try checkOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
            self.statement = try checkPointer(statement, from: "sqlite3_prepare_v2")
        }
        
        func bindParameters(_ parameters: [Parameter] = []) throws {
            try checkOK(sqlite3_clear_bindings(statement))
            
            var index: Int32 = 1
            for parameter in parameters {
                switch parameter {
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
        }
        
        func step() throws -> StepResult {
            let resultCode = try ResultCode(sqlite3_step(statement))
            switch resultCode {
            case .ROW:
                if !hasColumnNames {
                    let count = sqlite3_column_count(statement)
                    for index in 0..<count {
                        if let cName = sqlite3_column_name(statement, index) {
                            let name = String(cString: cName)
                            columnNames[name] = index
                        }
                    }
                    hasColumnNames = true
                }
                hasRow = true
                return .row
            case .DONE:
                hasRow = false
                return .done
            default:
                throw resultCode
            }
        }
        
        enum StepResult {
            case row
            case done
        }
        
        func read(column: String) throws -> Int {
            return Int(sqlite3_column_int(statement, try getIndex(column)))
        }
        
        func read(column: String) throws -> Int64 {
            return sqlite3_column_int64(statement, try getIndex(column))
        }
        
        func read(column: String) throws -> String {
            guard let cString = sqlite3_column_text(statement, try getIndex(column)) {
                fatalError("TODO: can this happen? When? Throw a better error.")
            }
            return String(cString: cString)
        }
        
        func read(column: String) throws -> Double {
            return sqlite3_column_double(statement, try getIndex(column))
        }
        
        private func getIndex(_ columnName: String) throws -> Int32 {
            guard let index = columnNames[columnName] else {
                throw ConnectionError.noSuchColumn(columnName, columnNames.keys.sorted())
            }
            return index
        }
        
        func reset() throws {
            hasRow = false
            try checkOK(sqlite3_reset(statement))
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
    let resultCode = try ResultCode(code)
    if resultCode != .OK {
        throw resultCode
    }
}

func checkPointer(_ pointer: OpaquePointer?, from functionName: String) throws -> OpaquePointer {
    guard let pointer = pointer else {
        throw SwiftDBError.unexpected("expected \(functionName) to set a pointer")
    }
    return pointer
}

enum ConnectionError: Error, CustomStringConvertible {
    case noSuchColumn(String, [String])

    public var description: String {
        switch self {
        case .noSuchColumn(let name, let names):
            return "No column called \(name) in results (available column: \(names))"
        }
    }
}
