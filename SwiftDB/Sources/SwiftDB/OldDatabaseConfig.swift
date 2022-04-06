import Foundation

// TODO remove this file

/// Used to configure a collection on a `Database`
public struct OldCollectionConfig {
    let type: Any.Type
    let typeId: ObjectIdentifier
    let tableName: String?
    private let untypedProperties: Any

    /// Configure a collection on a `Database`
    public static func collection<T: Codable>(
        _ type: T.Type,
        tableName: String? = nil,
        _ properties: OldPropertyConfig<T>...
    ) -> OldCollectionConfig {
        return OldCollectionConfig(
            type: type,
            typeId: ObjectIdentifier(type),
            tableName: tableName,
            untypedProperties: properties)
    }

    func typedPropertyConfigs<T>(_ type: T.Type) throws -> [OldPropertyConfig<T>] {
        guard let properties = untypedProperties as? [OldPropertyConfig<T>] else {
            throw SwiftDBError.unexpected(message: "type mismatch in \(Self.self): expected \(self.type) got \(type)")
        }
        return properties
    }
}

/// Used to configure an index on a collection
public struct OldPropertyConfig<Row: Codable>: Equatable {
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
    ) -> OldPropertyConfig {
        return OldPropertyConfig(keyPath: PartialCodableKeyPath(property), collation: collation, indices: indices)
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
    ) -> OldPropertyConfig {
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
