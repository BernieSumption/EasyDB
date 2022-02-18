import SQLite3
import Foundation

/// Wrapper around an SQLite C API `sqlite3_stmt` object providing a more Swifty API
class Statement {
    private let db: OpaquePointer
    private let statement: OpaquePointer
    private var columnNameToIndex = [String: Int]()
    private var parameterNameToIndex = [String: Int]()
    private var hasColumnNames = false
    private let sql: String
    
    /// True if the most recent call to `step()` returned `.done`
    ///
    /// Calling `step()` will throw an error if `isDone` is true
    private(set) var isDone = false
    
    /// True if the most recent call to `step()` returned `.row`.
    ///
    /// Calling any of the `readXXX()` functions will throw an error if `hasRow` is false
    private(set) var hasRow = false

    init(_ db: OpaquePointer, _ sql: String) throws {
        self.db = db
        self.sql = sql
        var statement: OpaquePointer?
        try SwiftDB.checkOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil), sql: sql, db: db)
        self.statement = try checkPointer(statement, from: "sqlite3_prepare_v2")
    }

    /// Bind `N` parameters to the statement in positions `1..N`, clearing any previously bound parameters.
    func bind(_ parameters: [DatabaseValue]) throws {
        try checkOK(sqlite3_clear_bindings(statement))

        var index: Int = 1
        for parameter in parameters {
            try bind(parameter, to: index)
            index += 1
        }
    }
    
    /// Bind a value to a parameter by index
    func bind(_ parameter: DatabaseValue, to index: Int) throws {
        let index = Int32(index)
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
    }
    
    /// Bind a value to a parameter by index
    func bind(_ parameter: DatabaseValue, to name: String) throws {
        try bind(parameter, to: getParameterIndex(name))
    }
    
    /// Get the index of a named parameter
    ///
    /// - Throws: SwiftDBError.noSuchParameter if there is no parameter with that name
    func getParameterIndex(_ name: String) throws -> Int {
        if let index = parameterNameToIndex[name] {
            return index
        }
        let index = Int(sqlite3_bind_parameter_index(statement, name))
        guard index > 0 else {
            // TODO: this should throw a ConnectionError with context and SQL
            throw SwiftDBError.noSuchParameter(name: name)
        }
        parameterNameToIndex[name] = index
        return index
    }

    /// Fetch the next row
    ///
    /// - Returns: `.row` if there is data to be read or `.done` if the end of the query has been reached
    /// - Throws: `SwiftDBError.noRow` if called again after returning `.done`
    func step() throws -> StepResult {
        if isDone {
            throw SwiftDBError.noRow
        }
        let resultCode = sqlite3_step(statement)
        switch resultCode {
        case SQLITE_ROW:
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
        case SQLITE_DONE:
            hasRow = false
            return .done
        default:
            try checkOK(resultCode) // should always throw
            throw SwiftDBError.unexpected(message: "Unexpected result code \(resultCode) returned from sqlite3_step()")
        }
    }

    /// The result of a call to `step()`
    enum StepResult {
        /// There is a row with data to read
        case row
        /// There are no more rows
        case done
    }
    
    func read(column name: String) throws -> DatabaseValue {
        return try read(column: try getColumnIndex(name))
    }
    
    func read(column index: Int) throws -> DatabaseValue {
        try checkRowAvailable()
        let index = Int32(index)
        let type = sqlite3_column_type(statement, index)
        
        switch type {
        case SQLITE_INTEGER:
            return .int(sqlite3_column_int64(statement, index))
            
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, index))
            
        case SQLITE_TEXT:
            guard let cString = sqlite3_column_text(statement, index) else {
                return .text("")
            }
            return .text(String(cString: cString))
            
        case SQLITE_BLOB:
            guard let bytes = sqlite3_column_blob(statement, index) else {
                return .blob(Data())
            }
            let count = Int(sqlite3_column_bytes(statement, index))
            return .blob(Data(bytes: bytes, count: count))
            
        case SQLITE_NULL:
            return .null
            
        default:
            throw SwiftDBError.unexpected(message: "sqlite3_column_type returned unknown code \(type)")
        }
    }
    
    func readNull(column name: String) throws -> Bool {
        return try readNull(column: try getColumnIndex(name))
    }
    
    func readNull(column index: Int) throws -> Bool {
        try checkRowAvailable()
        return sqlite3_column_type(statement, Int32(index)) == SQLITE_NULL
    }
    
    var columnNames: [String] {
        return [String](columnNameToIndex.keys)
    }
    
    var columnCount: Int {
        return columnNameToIndex.count
    }
    
    func hasColumn(_ columnName: String) -> Bool {
        return columnNameToIndex[columnName] != nil
    }

    private func getColumnIndex(_ columnName: String) throws -> Int {
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
        isDone = false
        try checkOK(sqlite3_reset(statement))
    }

    deinit {
        sqlite3_finalize(statement)
    }
    
    private func checkOK(_ code: @autoclosure () -> CInt) throws {
        try SwiftDB.checkOK(code(), sql: self.sql, db: db)
    }
}

// https://stackoverflow.com/questions/26883131/sqlite-transient-undefined-in-swift
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)


