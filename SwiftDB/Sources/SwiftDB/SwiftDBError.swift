public enum SwiftDBError: Error, CustomStringConvertible {
    case unexpected(String)

    public var description: String {
        switch self {
        case .unexpected(let message):
            return "Internal error: \(message) - this is a bug in SwiftDB that should be reported"
        }
    }
}
