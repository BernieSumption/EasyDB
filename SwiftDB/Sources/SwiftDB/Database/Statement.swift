import SQLite3
import Foundation

/// Wrapper around an SQLite C API `sqlite3_stmt` object providing a more Swifty API
class Statement {
    private let statement: OpaquePointer
    private var columnNameToIndex = [String: Int]()
    private var hasColumnNames = false
    
    private(set) var hasRow = false

    init(_ db: OpaquePointer, _ sql: String) throws {
        var statement: OpaquePointer?
        try checkOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
        self.statement = try checkPointer(statement, from: "sqlite3_prepare_v2")
    }

    func bindParameters(_ parameters: [Parameter]) throws {
        try checkOK(sqlite3_clear_bindings(statement))

        var index: Int32 = 1
        for parameter in parameters {
            switch parameter {
            case .double(let double):
                try checkOK(sqlite3_bind_double(statement, index, double))
            case .int(let int):
                try checkOK(sqlite3_bind_int64(statement, index, int))
            case .null:
                try checkOK(sqlite3_bind_null(statement, index))
            case .text(let string):
                try checkOK(sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT))
            case .blob(let data):
                try data.withUnsafeBytes { bytes in
                    try checkOK(sqlite3_bind_blob(
                        statement, index, bytes.baseAddress, Int32(bytes.count),
                        SQLITE_TRANSIENT))
                }
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
                        columnNameToIndex[name] = Int(index)
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
    
    func readNull(column name: String) throws -> Bool {
        return try readNull(column: try getIndex(name))
    }
    
    func readNull(column index: Int) throws -> Bool {
        try checkRowAvailable()
        return sqlite3_column_type(statement, Int32(index)) == SQLITE_NULL
    }

    func readInt(column name: String) throws -> Int64 {
        return try readInt(column: try getIndex(name))
    }
    
    func readInt(column index: Int) throws -> Int64 {
        try checkRowAvailable()
        return sqlite3_column_int64(statement, Int32(index))
    }

    func readText(column name: String) throws -> String {
        return try readText(column: try getIndex(name))
    }
    
    func readText(column index: Int) throws -> String {
        try checkRowAvailable()
        guard let cString = sqlite3_column_text(statement, Int32(index)) else {
            return ""
        }
        let s = String(cString: cString)
        return s
    }
    
    func readBlob(column name: String) throws -> Data {
        return try readBlob(column: try getIndex(name))
    }
    
    func readBlob(column index: Int) throws -> Data {
        try checkRowAvailable()
        guard let bytes = sqlite3_column_blob(statement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(statement, Int32(index)))
        return Data(bytes: bytes, count: count)
    }
    
    func readDouble(column name: String) throws -> Double {
        return try readDouble(column: try getIndex(name))
    }
    
    func readDouble(column index: Int) throws -> Double {
        try checkRowAvailable()
        return sqlite3_column_double(statement, Int32(index))
    }
    
    var columnNames: [String] {
        return [String](columnNameToIndex.keys)
    }
    
    func hasColumn(_ columnName: String) -> Bool {
        return columnNameToIndex[columnName] != nil
    }

    private func getIndex(_ columnName: String) throws -> Int {
        guard let index = columnNameToIndex[columnName] else {
            throw SwiftDBError.noSuchColumn(columnName: columnName, availableColumns: columnNames)
        }
        return index
    }
    
    private func checkRowAvailable() throws {
        if !hasRow {
            throw SwiftDBError.noRow
        }
    }

    func reset() throws {
        hasRow = false
        try checkOK(sqlite3_reset(statement))
    }

    deinit {
        sqlite3_finalize(statement)
    }
}

// https://stackoverflow.com/questions/26883131/sqlite-transient-undefined-in-swift
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum Parameter {
    case double(Double)
    case int(Int64)
    case null
    case text(String)
    case blob(Data)
}
