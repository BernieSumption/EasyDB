import Foundation


public struct CollectionConfig {
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
            typeId: ObjectIdentifier(type),
            tableName: tableName,
            disableUniqueId: disableUniqueId,
            indices: indices)
    }
    
    
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
}


// TODO: remove this or use it throughout
struct TypeScopedSingleton {
    private var instances = [ObjectIdentifier: Any]()
    
    mutating func getOrCreate<K, V>(_ type: K.Type, _ create: () throws -> V) rethrows -> V {
        let typeId = ObjectIdentifier(type)
        if let instance = instances[typeId] {
            guard let instanceV = instance as? V else {
                fatalError("expected cached instance to be of type \(V.self) but got \(instance)")
            }
            return instanceV
        }
        let instance = try create()
        instances[typeId] = instance
        return instance
    }
    
    // TODO: this is in here temporarily, we need to move V to the class level, or at least not pass an iniitialiser to this method just for typing
    func getIfPresent<K, V>(_ type: K.Type, _ create: () throws -> V) rethrows -> V? {
        let typeId = ObjectIdentifier(type)
        if let instance = instances[typeId] {
            guard let instanceV = instance as? V else {
                fatalError("expected cached instance to be of type \(V.self) but got \(instance)")
            }
            return instanceV
        }
        return nil
    }
}
