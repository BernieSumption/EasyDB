import Foundation

/// Used to configure a collection on a `Database`
public struct CollectionConfig {
    let type: Any.Type
    let typeId: ObjectIdentifier
    let tableName: String?
    let disableUniqueId: Bool
    private let properties: Any
    
    /// Configure a collection on a `Database`
    public static func collection<T: Codable>(
        _ type: T.Type,
        tableName: String? = nil,
        disableUniqueId: Bool = false,
        _ properties: PropertyConfig<T>...
    ) -> CollectionConfig {
        return CollectionConfig(
            type: type,
            typeId: ObjectIdentifier(type),
            tableName: tableName,
            disableUniqueId: disableUniqueId,
            properties: properties)
    }
    
    /// Used to configure an index on a collection
    public struct PropertyConfig<Row: Codable>: Equatable {
        let keyPath: PartialCodableKeyPath<Row>
        let kind: Kind
        let collation: Collation?
        
        /// Add an index to a property
        public static func index<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            unique: Bool = false,
            collation: Collation? = nil
        ) -> PropertyConfig {
            return PropertyConfig(
                keyPath: PartialCodableKeyPath(keyPath),
                kind: .index(unique: unique),
                collation: collation
            )
        }
        
        /// A convenience shortcut for adding a unique index to a property  with `.index(... unique:true)`)
        public static func unique<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            collation: Collation? = nil
        ) -> PropertyConfig {
            return index(keyPath, unique: true, collation: collation)
        }
        
        /// Set the default collation for all indices, sorting and filtering operations on this property.
        public static func collation<V: Codable>(_ keyPath: KeyPath<Row, V>, _ collation: Collation) -> PropertyConfig {
            return PropertyConfig(
                keyPath: PartialCodableKeyPath(keyPath),
                kind: .defaultCollation,
                collation: collation
            )
        }
        
        enum Kind: Equatable {
            case index(unique: Bool)
            case defaultCollation
        }
    }
    
    func build<T: Codable>(_ type: T.Type) throws -> Collection<T>.Config {
        guard let properties = self.properties as? [PropertyConfig<T>] else {
            throw SwiftDBError.unexpected(message: "type mismatch in CollectionConfig: expected \(self.type) got \(type)")
        }
        
        return Collection<T>.Config(
            tableName: tableName,
            disableUniqueId: disableUniqueId,
            properties: properties)
    }
}

public protocol CustomTableName {
    static var tableName: String { get }
}
