import Foundation
public enum EasyDBError: Error, CustomStringConvertible {

    /// An attempt to access a column that does not exist in the current results.
    case noSuchColumn(columnName: String, availableColumns: [String])

    /// An attempt to bind a parameter that does not exist in the current query
    case noSuchParameter(name: String)

    /// An attempt to read data from a statement when no row is available - either `step()` has not
    /// been called, or returned `StepResult.done`
    case noRow

    /// Data was in the wrong format
    case codingError(message: String, codingPath: [CodingKey])

    /// An unexpected error - this is an indication of a bug in EasyDB.
    case unexpected(message: String)

    /// A feature implied by the API is not implemented.
    case notImplemented(feature: String)

    /// Invalid data was passed to an API method
    case misuse(message: String)

    /// An SQLite error was thrown
    case sqliteError(resultCode: ResultCode, message: String?, sql: String?)

    public var description: String {
        switch self {
        case .noSuchColumn(let name, let available):
            return "No column called \(name) in results (available columns: \(available.sorted()))"
        case .noSuchParameter(let name):
            return "No parameter called \(name) in query"
        case .noRow:
            return "No row data is available to read"
        case .codingError(let message, let codingPath):
            let path = codingPath.map(\.stringValue).joined(separator: ".")
            return "Error decoding property \(path): \(message)"
        case .unexpected(let message):
            return "Internal error: \(message) - this is a bug in EasyDB that should be reported"
        case .notImplemented(let feature):
            return "\(feature) is not implemented - if this would be useful to you please make a feature request as a GitHub issue and give some details about your use case"
        case .misuse(let message): return message
        case .sqliteError(let resultCode, let message, let sql):
            return "\(resultCode) \(message ?? "(no message)"); while executing \"\(sql ?? "(no query)")\""
        }
    }

    var isSqliteReadOnly: Bool {
        if case .sqliteError(let resultCode, _, _) = self {
            return resultCode == .READONLY
        }
        return false
    }
}
