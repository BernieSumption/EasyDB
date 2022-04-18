import Foundation

enum ReflectionError: Error, CustomStringConvertible {
    case noValues(Any.Type)
    case invalidRecordType(Any.Type, String)
    case keyPathNotFound(Any.Type)
    case decodingError(Any.Type, Error)

    public var description: String {
        switch self {
        case .noValues(let type):
            return "Can't create an instance of \(type) because no values were provided, add conformance to \(SampleValueSource.self)"
        case .invalidRecordType(let type, let message):
            return "\(type) can't be used as a record type: \(message)"
        case .keyPathNotFound(let type):
            return "The provided KeyPath can't be mapped to a property of \(type) - note that array and dictionary subscript KeyPaths e.g. \\TypeName.myArray[0] are not supported"
        case .decodingError(let type, let error):
            // NOTE: this string is documented, if you change it update the docs
            return "Error thrown from \(type).init(from:) \"\(error)\""
        }
    }
}
