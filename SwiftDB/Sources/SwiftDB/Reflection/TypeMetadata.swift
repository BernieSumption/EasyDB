class TypeMetadata {
    private var propertyConfigs = [String: [PropertyConfig]]()
    private var currentPropertyName: String?

    /// Called we start encoding a top-level property on a type
    func startTopLevelProperty(propertyName: String) throws {
        if let currentPropertyName = currentPropertyName {
            throw SwiftDBError.unexpected(message: "Can't start encoding \(propertyName), already encoding \(currentPropertyName)")
        }
        currentPropertyName = propertyName
    }

    /// Called we finish encoding a top-level property on a type - i.e. when we have finished the chain of single value
    /// encoding containers that correspond to metadata annotations property wrappers like @Index or @Unique
    func finishTopLevelProperty() {
        currentPropertyName = nil
    }

    /// Add a config to the current property
    public func addPropertyConfig(_ config: PropertyConfig) throws {
        guard let propertyName = currentPropertyName else {
            throw SwiftDBError.unexpected(message: "call to addPropertyConfig but no property is currently being encoded")
        }
        var configs = getPropertyConfigs(propertyName)
        configs.append(config)
        propertyConfigs[propertyName] = configs
    }

    func getPropertyConfigs(_ propertyName: String) -> [PropertyConfig] {
        return propertyConfigs[propertyName] ?? []
    }

    static let userInfoKey = CodingUserInfoKey(rawValue: String(describing: TypeMetadata.self))!
}

enum PropertyConfig: Equatable {
    case collation(Collation)
    case index(unique: Bool)
    case additionalIndex(unique: Bool, Collation)
    case noDefaultUniqueId
}

@propertyWrapper
public struct Collate<Value: Codable>: Codable, MetadataAnnotation {
    public var wrappedValue: Value

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }

    public init(from decoder: Decoder) throws {
        if let typeMetadata = decoder.userInfo[TypeMetadata.userInfoKey] as? TypeMetadata {
            try typeMetadata.addPropertyConfig(.collation(.caseInsensitive))
        }
        let container = try decoder.singleValueContainer()
        wrappedValue = try container.decode(Value.self)
    }
}

protocol MetadataAnnotation {}
