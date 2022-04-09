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

public enum PropertyConfig: Equatable {
    case collation(Collation)
    case index(unique: Bool)
    case noDefaultUniqueId
}

public protocol IsConfigurationAnnotation {}

public protocol ConfigurationAnnotation: Codable, Equatable, IsConfigurationAnnotation {
    associatedtype Value: Codable, Equatable

    var wrappedValue: Value { get set }

    init(wrappedValue: Value)

    static var propertyConfig: PropertyConfig { get }
}

public extension ConfigurationAnnotation {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }

    init(from decoder: Decoder) throws {
        if let typeMetadata = decoder.userInfo[TypeMetadata.userInfoKey] as? TypeMetadata {
            try typeMetadata.addPropertyConfig(Self.propertyConfig)
        }
        let container = try decoder.singleValueContainer()
        self.init(wrappedValue: try container.decode(Value.self))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

@propertyWrapper
public struct CollateCaseInsensitive<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .collation(.caseInsensitive)
    }
}

@propertyWrapper
public struct CollateLocalized<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .collation(.localized)
    }
}

@propertyWrapper
public struct CollateLocalizedCaseInsensitive<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .collation(.localizedCaseInsensitive)
    }
}

@propertyWrapper
public struct Unique<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .index(unique: true)
    }
}

@propertyWrapper
public struct Index<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .index(unique: true)
    }
}

/// Disable the default behaviour of applying a unique index to the `id` column of an `Identifiable` collection
@propertyWrapper
public struct NotUnique<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .noDefaultUniqueId
    }
}
