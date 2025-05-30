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
    private let logSQL: SQLLogger
    private let connectionName: String

    /// True if the most recent call to `step()` returned `.row`.
    ///
    /// Calling any of the `readXXX()` functions will throw an error if `hasRow` is false
    private(set) var hasRow = false

    private var parameters = [Int: String]()

    init(_ db: OpaquePointer, _ sql: String, logSQL: SQLLogger, connectionName: String) throws {
        self.db = db
        self.sql = sql
        self.connectionName = connectionName
        self.logSQL = logSQL
        var statement: OpaquePointer?
        try checkOK(sqlite3_prepare_v2(db, sql, -1, &statement, nil), sql: sql, db: db)
        self.statement = try checkPointer(statement, from: "sqlite3_prepare_v2")
    }

    func clearBoundParameters() throws {
        self.parameters.removeAll()
        try checkResult(sqlite3_clear_bindings(statement))
    }

    /// Bind `N` parameters to the statement in positions `1..N`, clearing any previously bound parameters.
    func bind(_ parameters: [DatabaseValue]) throws {
        try clearBoundParameters()

        var index: Int = 1
        for parameter in parameters {
            try bind(parameter, to: index)
            index += 1
        }
    }

    /// Bind a value to a parameter by position, where `1` is the leftmost parameter
    func bind(_ parameter: DatabaseValue, to position: Int) throws {
        if logSQL.enabled {
            self.parameters[position] = parameter.debugDescription
        }
        let index = Int32(position)
        switch parameter {
        case .double(let double):
            try checkResult(sqlite3_bind_double(statement, index, double))
        case .int(let int):
            try checkResult(sqlite3_bind_int64(statement, index, int))
        case .null:
            try checkResult(sqlite3_bind_null(statement, index))
        case .text(let string):
            try checkResult(sqlite3_bind_text(statement, index, string, -1, sqliteTransient))
        case .blob(let data):
            try data.withUnsafeBytes { bytes in
                try checkResult(sqlite3_bind_blob(
                    statement, index, bytes.baseAddress, Int32(bytes.count),
                    sqliteTransient))
            }
        }
    }

    /// Bind a value to a parameter by name
    func bind(_ parameter: DatabaseValue, to name: String) throws {
        try bind(parameter, to: getParameterIndex(name))
    }

    /// Get the index of a named parameter
    ///
    /// - Throws: EasyDBError.noSuchParameter if there is no parameter with that name
    func getParameterIndex(_ name: String) throws -> Int {
        if let index = parameterNameToIndex[name] {
            return index
        }
        let index = Int(sqlite3_bind_parameter_index(statement, name))
        guard index > 0 else {
            throw EasyDBError.noSuchParameter(name: name)
        }
        parameterNameToIndex[name] = index
        return index
    }

    /// Fetch the next row
    ///
    /// - Returns: `.row` if there is data to be read or `.done` if the end of the query has been reached
    /// - Throws: `EasyDBError.noRow` if called again after returning `.done`
    func step() throws -> StepResult {
        if !hasRow && logSQL.enabled {
            let sql = self.sql
            let parameters = parameters
                .sorted(by: { $0.key < $1.key })
                .map({ "\($0.key)=\($0.value)" })
                .joined(separator: ", ")

            logSQL.log("Executing statement on \(connectionName): \"\(sql)\" (parameters: \(parameters))")
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
            try checkResult(resultCode) // should always throw
            throw EasyDBError.unexpected(message: "Unexpected result code \(resultCode) returned from sqlite3_step()")
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
            throw EasyDBError.unexpected(message: "sqlite3_column_type returned unknown code \(type)")
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
            throw EasyDBError.noSuchColumn(columnName: columnName, availableColumns: columnNames)
        }
        return index
    }

    private func checkRowAvailable() throws {
        if !hasRow {
            throw EasyDBError.noRow
        }
    }

    func reset() {
        hasRow = false
        sqlite3_reset(statement)
    }

    deinit {
        sqlite3_finalize(statement)
    }

    private func checkResult(_ code: CInt) throws {
        try checkOK(code, sql: self.sql, db: db)
    }
}

// https://stackoverflow.com/questions/26883131/sqlite-transient-undefined-in-swift
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
