import Foundation

enum ReflectionError: Error, CustomStringConvertible {
    case invalidRecordType(Any.Type, String)
    case decodingError(Any.Type, Error)

    var description: String {
        switch self {
        case .invalidRecordType(let type, let message):
            return "\(type) can't be used as a record type: \(message)"
        case .decodingError(let type, let error):
            // NOTE: this string is documented, if you change it update the docs
            return "Error thrown from \(type).init(from:) \"\(error)\""
        }
    }
}
