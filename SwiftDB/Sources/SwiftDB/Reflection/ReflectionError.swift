enum ReflectionError: Error, CustomStringConvertible {
    case noValues(Any.Type)
    case invalidRecordType(Any.Type, String)
    case keyPathNotFound(Any.Type)

    public var description: String {
        switch self {
        case .noValues(let type):
            // TODO: when we have an API for providing values, add it to this error message
            return
                "Could not discriminate properties of type \(type) because no values were provided"
        case .invalidRecordType(let type, let message):
            return "\(type) can't be used as a record type: \(message)"
        case .keyPathNotFound(let type):
            return
                "The provided KeyPath can't be mapped to a property of \(type) - note that array and dictionary subscript KeyPaths e.g. \\TypeName.myArray[0] are not supported"
        }
    }
}
