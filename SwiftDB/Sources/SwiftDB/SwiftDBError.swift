public enum SwiftDBError: Error, CustomStringConvertible {
    /// An attempt to access a column that does not exist in the current results. The associated values
    /// are the invalid column names and the available column names.
    case noSuchColumn(columnName: String, availableColumns: [String])
    
    /// An attempt to read data from a statement when no row is available - either `step()` has not
    /// been called, or returned `StepResult.done`
    case noRow
    
    /// Data was in the wrong format
    case decodingError(message: String, codingPath: [CodingKey])
    
    /// An unexpected error - this is an indication of a bug in SwiftDB. The associated value is an error message.
    case unexpected(message: String)

    public var description: String {
        switch self {
        case .noSuchColumn(let name, let available):
            return "No column called \(name) in results (available columns: \(available.sorted()))"
        case .noRow:
            return "No row data is available to read"
        case .decodingError(let message, let codingPath):
            let path = codingPath.map(\.stringValue).joined(separator: ".")
            return "Decoding error: \(message) at \(path)"
        case .unexpected(let message):
            return "Internal error: \(message) - this is a bug in SwiftDB that should be reported"
        }
    }
}
