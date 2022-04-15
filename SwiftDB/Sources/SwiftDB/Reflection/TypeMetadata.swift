class TypeMetadata {
    private var propertyConfigs = [String: [PropertyConfig]]()
    private var lastPropertyName: String?
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
        if let currentPropertyName = currentPropertyName {
            lastPropertyName = currentPropertyName
        }
        currentPropertyName = nil
    }

    /// Add a config to the current property
    ///
    /// - Throws: `TypeMetadataError.notAtRootLevel` if we're not encoding a root property
    public func addPropertyConfig(_ config: PropertyConfig) throws {
        guard let propertyName = currentPropertyName else {
            throw TypeMetadataError.notAtRootLevel
        }
        var configs = propertyConfigs[propertyName] ?? []

        if configs.contains(config) {
            throw TypeMetadataError.duplicate
        }

        configs.append(config)
        propertyConfigs[propertyName] = configs
    }

    func getConfigs(_ propertyName: String) -> [PropertyConfig] {
        return propertyConfigs[propertyName] ?? []
    }

    func getCombinedConfig(_ propertyName: String, isId: Bool) throws -> CombinedPropertyConfig {
        var resultCollation: Collation?
        var resultIndex: CombinedPropertyConfig.IndexKind?

        var noDefaultUniqueId: Bool = false
        if let configs = propertyConfigs[propertyName] {
            for config in configs {
                switch config {
                case .collation(let collation):
                    if let resultCollation = resultCollation {
                        throw SwiftDBError.misuse(message: "Multiple collations specified for \(propertyName) - \(resultCollation.name) then \(collation.name)")
                    }
                    resultCollation = collation
                case .index(unique: let unique):
                    if unique {
                        if noDefaultUniqueId {
                            throw SwiftDBError.misuse(message: "both @NotUnique and @Unique specified")
                        }
                        resultIndex = .unique
                    } else if resultIndex != .unique {
                        resultIndex = .regular
                    }
                case .noDefaultUniqueId:
                    if !isId {
                        let annotationName = typeNameWithoutGenerics(NotUnique<Int>.self)
                        throw SwiftDBError.misuse(message: "@\(annotationName) can only be applied to the id property of an Identifiable type")
                    }
                    if resultIndex == .unique {
                        throw SwiftDBError.misuse(message: "both @Unique and @NotUnique specified")
                    }
                    noDefaultUniqueId = true
                }
            }
        }

        if isId && !noDefaultUniqueId {
            resultIndex = .unique
        }

        return CombinedPropertyConfig(
            collation: resultCollation ?? .string,
            index: resultIndex)
    }

    static let userInfoKey = CodingUserInfoKey(rawValue: String(describing: TypeMetadata.self))!
}

enum TypeMetadataError: Error {
    case notAtRootLevel
    case duplicate

    func message(annotationName: String) -> String {
        switch self {
        case .notAtRootLevel:
            return "configuration property wrapper @\(annotationName) encountered below the top level type"
        case .duplicate:
            return "duplicate configuration property wrapper @\(annotationName) encountered"
        }
    }
}

public enum PropertyConfig: Equatable {
    case collation(Collation)
    case index(unique: Bool)
    case noDefaultUniqueId
}

struct CombinedPropertyConfig: Equatable {
    let collation: Collation
    let index: IndexKind?

    enum IndexKind {
        case unique, regular
    }
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
            do {
                try typeMetadata.addPropertyConfig(Self.propertyConfig)
            } catch let error as TypeMetadataError {
                let annotationName = typeNameWithoutGenerics(Self.self)
                throw SwiftDBError.codingError(
                    message: error.message(annotationName: annotationName),
                    codingPath: decoder.codingPath)
            }
        }
        let container = try decoder.singleValueContainer()
        self.init(wrappedValue: try container.decode(Value.self))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

private func typeNameWithoutGenerics<T>(_ type: T.Type) -> String {
    let name = String(describing: type)
    if let index = name.firstIndex(of: "<") {
        return String(name[name.startIndex..<index])
    }
    return name
}

@propertyWrapper
public struct CollateBinary<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static var propertyConfig: PropertyConfig {
        return .collation(.binary)
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
        return .index(unique: false)
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
