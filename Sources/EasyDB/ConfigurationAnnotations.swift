/// Protocol for a property wrapper that provides a `PropertyConfig` for a property on a record type
public protocol ConfigurationAnnotation: Codable, Equatable, IsConfigurationAnnotation {
    associatedtype Value: Codable, Equatable

    var wrappedValue: Value { get set }

    init(wrappedValue: Value)

    static var propertyConfig: PropertyConfig { get }
}

/// Configuration for a property on a record type
public enum PropertyConfig: Equatable {
    case collation(Collation)
    case index(unique: Bool)
}

/// A marker protocol used the check whether a type conforms to ConfigurationAnnotation
public protocol IsConfigurationAnnotation {}

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
                throw EasyDBError.codingError(
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

/// Apply this as a property wrapper to use `Collation.binary` for indices, filters and sorting on this property
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

/// Apply this as a property wrapper to use `Collation.caseInsensitive` for indices, filters and sorting on this property
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

/// Apply this as a property wrapper to use `Collation.localized` for indices, filters and sorting on this property
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

/// Apply this as a property wrapper to use `Collation.localizedCaseInsensitive` for indices, filters and sorting on this property
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

/// Apply this as a property wrapper to add a unique index to this property.
///
/// Adding this will override `@Index` and result in a single, unique index.
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

/// Apply this as a property wrapper to add a regular index to this property
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
