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
    
    /// Used to configure an index on a collection
    public struct PropertyConfig<Row: Codable>: Equatable {
        let keyPath: PartialCodableKeyPath<Row>
        let collation: Collation?
        let indices: [Index]
        
        public static func column<T: Codable>(
            _ keyPath: KeyPath<Row, T>,
            collate: Collation? = nil,
            _ indices: Index...
        ) -> PropertyConfig {
            return PropertyConfig(keyPath: PartialCodableKeyPath(keyPath), collation: collate, indices: indices)
        }
        
        public static func column<T: Codable>(
            _ keyPath: KeyPath<Row, T>,
            collate: Collation? = nil,
            unique: Bool
        ) -> PropertyConfig {
            return column(keyPath, collate: collate, .index(unique: unique))
        }
        
        public struct Index: Equatable {
            let collate: Collation?
            let unique: Bool
            
            public static func index(unique: Bool = false, collate: Collation? = nil) -> Index {
                return Index(collate: collate, unique: unique)
            }
        }
    }
    
    func typedPropertyConfigs<T>(_ type: T.Type) throws -> [PropertyConfig<T>] {
        guard let properties = untypedProperties as? [PropertyConfig<T>] else {
            throw SwiftDBError.unexpected(message: "type mismatch in CollectionConfig: expected \(self.type) got \(type)")
        }
        return properties
    }
}

public protocol CustomTableName {
    static var tableName: String { get }
}
