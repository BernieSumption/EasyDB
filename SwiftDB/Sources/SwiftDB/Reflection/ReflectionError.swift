enum ReflectionError: Error, CustomStringConvertible {
    case noValues(Any.Type)
    case invalidRecordType(Any.Type, String)

    public var description: String {
        switch self {
        case .noValues(let type):
            // TODO: when we have an API for providing values, add it to this error message
            return
                "Could not discriminate properties of type \(type) because no values were provided"
        case .invalidRecordType(let type, let message):
            return "\(type) can't be used as a record type: \(message)"
        }
    }
}
