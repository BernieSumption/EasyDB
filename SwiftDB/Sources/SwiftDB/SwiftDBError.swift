public enum SwiftDBError: Error, CustomStringConvertible {
    /// An attempt to access a column that does not exist in the current results.
    case noSuchColumn(columnName: String, availableColumns: [String])
    
    /// An attempt to read data from a statement when no row is available - either `step()` has not
    /// been called, or returned `StepResult.done`
    case noRow
    
    /// Data was in the wrong format
    case decodingError(message: String, codingPath: [CodingKey])
    
    /// An unexpected error - this is an indication of a bug in SwiftDB.
    case unexpected(message: String)
    
    /// A feature implied by the API is not implemented.
    case notImplemented(feature: String)

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
        case .notImplemented(let feature):
            return "\(feature) is not implemented - if this would be useful to you please make a feature request as a GitHub issue"
        }
    }
}
