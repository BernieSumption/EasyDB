import Foundation

/// Used to configure a collection on a `Database`
public struct CollectionConfig {
    let type: Any.Type
    let typeId: ObjectIdentifier
    let tableName: String?
    private let untypedProperties: Any

    /// Configure a collection on a `Database`
    public static func collection<T: Codable>(
        _ type: T.Type,
        tableName: String? = nil,
        _ properties: PropertyConfig<T>...
    ) -> CollectionConfig {
        return CollectionConfig(
            type: type,
            typeId: ObjectIdentifier(type),
            tableName: tableName,
            untypedProperties: properties)
    }

    func typedPropertyConfigs<T>(_ type: T.Type) throws -> [PropertyConfig<T>] {
        guard let properties = untypedProperties as? [PropertyConfig<T>] else {
            throw SwiftDBError.unexpected(message: "type mismatch in CollectionConfig: expected \(self.type) got \(type)")
        }
        return properties
    }
}

/// Used to configure an index on a collection
public struct PropertyConfig<Row: Codable>: Equatable {
    let keyPath: PartialCodableKeyPath<Row>
    let collation: Collation?
    let indices: [Index]

    /// Configure a column setting multiple indices
    ///
    /// - Parameters:
    ///   - property: A KeyPath indicating the property to configure e.g. `\.myProperty`
    ///   - collation: an optional default collation for the property, see TODO: collation docs URL
    ///   - indices: any number of `Index` instances, e.g. `.unique()`
    public static func column<T: Codable>(
        _ property: KeyPath<Row, T>,
        collation: Collation? = nil,
        _ indices: Index...
    ) -> PropertyConfig {
        return PropertyConfig(keyPath: PartialCodableKeyPath(property), collation: collation, indices: indices)
    }

    /// A convenience method used to create a single unique index or disable the default behaviour of
    /// creating a unique index on the `id` property if it exists
    ///
    /// - Parameters:
    ///   - property: A KeyPath indicating the property to configure e.g. `\.myProperty`
    ///   - collation: an optional default collation for the property, see TODO: collation docs URL
    ///   - unique: `true` to create a unique index, `false` to disable the default behaviour of
    ///             creating a unique index on the `id` property if it exists
    public static func column<T: Codable>(
        _ property: KeyPath<Row, T>,
        collation: Collation? = nil,
        unique: Bool
    ) -> PropertyConfig {
        return column(
            property,
            collation: collation,
            unique ? .index(unique: true) : .noDefaultUniqueId())
    }

    /// Configure an index
    public struct Index: Equatable {
        let kind: IndexKind

        /// Add an index
        public static func index(unique: Bool = false, collation: Collation? = nil) -> Index {
            return Index(kind: .index(unique: unique, collation: collation))
        }

        /// Disable the default behaviour of creating a unique index on the `id` property if it exists
        public static func noDefaultUniqueId() -> Index {
            return Index(kind: .noDefaultUniqueId)
        }
    }

    enum IndexKind: Equatable {
        case index(unique: Bool, collation: Collation?)
        case noDefaultUniqueId
    }
}

public protocol CustomTableName {
    static var tableName: String { get }
}

public enum SQLLogger {
    case none
    case print
    case custom((String) -> Void)

    func log(_ message: String) {
        switch self {
        case .print: Swift.print(message)
        case .custom(let callback): callback(message)
        case .none: break
        }
    }

    var enabled: Bool {
        if case .none = self {
            return false
        }
        return true
    }
}
