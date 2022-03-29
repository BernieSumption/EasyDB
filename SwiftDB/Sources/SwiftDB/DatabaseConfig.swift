import Foundation

/// Used to configure a collection on a `Database`
public struct CollectionConfig {
    let type: Any.Type
    let typeId: ObjectIdentifier
    let tableName: String?
    let disableUniqueId: Bool
    private let indices: Any
    
    /// Configure a collection on a `Database`
    public static func collection<T: Codable>(
        _ type: T.Type,
        tableName: String? = nil,
        disableUniqueId: Bool = false,
        _ indices: Index<T>...
    ) -> CollectionConfig {
        return CollectionConfig(
            type: type,
            typeId: ObjectIdentifier(type),
            tableName: tableName,
            disableUniqueId: disableUniqueId,
            indices: indices)
    }
    
    /// Used to configure an index on a collection
    public struct Index<Row: Codable>: Equatable {
        let keyPath: PartialCodableKeyPath<Row>
        let unique: Bool
        let collation: Collation?
        
        /// Add an index to a property
        public static func index<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            unique: Bool = false,
            collation: Collation? = nil
        ) -> Index {
            return Index(
                keyPath: PartialCodableKeyPath(keyPath),
                unique: unique,
                collation: collation
            )
        }

        /// A convenience shortcut for adding a unique index to a property  with `.index(... unique:true)`)
        public static func unique<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            collation: Collation? = nil
        ) -> Index {
            return index(keyPath, unique: true, collation: collation)
        }
    }
    
    func build<T: Codable>(_ type: T.Type) throws -> Collection<T>.Config {
        guard let indices = self.indices as? [Index<T>] else {
            throw SwiftDBError.unexpected(message: "type mismatch in CollectionConfig: expected \(self.type) got \(type)")
        }
        
        return Collection<T>.Config(
            tableName: tableName,
            disableUniqueId: disableUniqueId,
            indices: indices)
    }
}

public protocol CustomTableName {
    static var tableName: String { get }
}
