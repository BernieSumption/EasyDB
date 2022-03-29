

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
