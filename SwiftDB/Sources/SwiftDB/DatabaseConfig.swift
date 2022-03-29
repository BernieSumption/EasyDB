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
            collation: Collation? = nil,
            _ indices: Index...
        ) -> PropertyConfig {
            return PropertyConfig(keyPath: PartialCodableKeyPath(keyPath), collation: collation, indices: indices)
        }
        
        public static func column<T: Codable>(
            _ keyPath: KeyPath<Row, T>,
            collation: Collation? = nil,
            unique: Bool
        ) -> PropertyConfig {
            return column(keyPath, collation: collation, .index(unique: unique))
        }
        
        public struct Index: Equatable {
            let collation: Collation?
            let unique: Bool
            
            public static func index(unique: Bool = false, collation: Collation? = nil) -> Index {
                return Index(collation: collation, unique: unique)
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
