/// Locates key paths within a type's coded representation
///
/// Here's an example:
///
/// ```
/// struct Person: Codable {
///     let id: String
///     let name: String
/// }
/// let mapper = KeyPathMapper(Person.self)
/// print(try mapper.propertyPath(for: \.id))   // prints ["id"]
/// print(try mapper.propertyPath(for: \.name)) // prints ["name"]
/// ```
///
/// Swift does not provide a convenient API to do this, so we need to do be crafty. When given a KeyPath, we
/// can't directly find out what property it is for. `\Person.id` and `\Person.name` look the same - they are
/// KeyPath objects that return strings. So we construct a special `Person` instance that has known values at
/// each property, e.g. `let sample = Person(id: "0", name: "1")`. Then given a key path `k`, if
/// `sample[keyPath: k]` returns `"1"` then we know that `k` must be a key path to `name`.
///
/// In practice it's a bit more complicated than that, because boolean properties can only have 2 values so if we only
/// had one sample instance, we'd only be able to differentiate two boolean properties. So in fact we have a list of
/// instances containing enough samples to differentiate all properties. See `MultifariousDecoder` for details
/// on how this works.
class KeyPathMapper<T: Codable> {
    private let instances: [T]
    private let valuesToPropertyPath: [[Encoded]: [String]]
    private var keyPathToPropertyPath = [AnyKeyPath: [String]]()

    private init(_ type: T.Type) throws {
        instances = try MultifariousDecoder.instances(for: type)
        let jsonInstances = try instances.map({ try Encoded($0) })
        guard let first = jsonInstances.first else {
            throw SwiftDBError.unexpected(message: "Multifarious.instances was empty")
        }
        let propertyPaths = first.propertyPaths
        let differing = jsonInstances.first(where: { Set($0.propertyPaths) != Set(propertyPaths) })
        if let differing = differing {
            throw SwiftDBError.unexpected(message:
                "Multifarious.instances have different structures, \(propertyPaths) and \(differing.propertyPaths)"
            )
        }
        var valuesToPropertyPath = [[Encoded]: [String]]()
        for propertyPath in propertyPaths {
            let allValues = try jsonInstances.map { json -> Encoded in
                guard let value = json.value(at: propertyPath) else {
                    throw SwiftDBError.unexpected(message: "Instance as no value at \(propertyPath)")
                }
                return value
            }
            if valuesToPropertyPath[allValues] != nil {
                throw SwiftDBError.unexpected(message: "Instances contain multiple \(allValues)")
            }
            valuesToPropertyPath[allValues] = propertyPath
        }
        self.valuesToPropertyPath = valuesToPropertyPath
    }
    
    /// Given a KeyPath, return the path of key names that locates the same value in the type's encoded representation
    func propertyPath<V: Encodable>(for keyPath: KeyPath<T, V>) throws -> [String] {
        return try propertyPath(for: PartialCodableKeyPath(keyPath))
    }
    
    /// A type-erased version of `propertyPath(for:)`
    func propertyPath(for keyPath: PartialCodableKeyPath<T>) throws -> [String] {
        if let cached = keyPathToPropertyPath[keyPath.cacheKey] {
            return cached
        }
        let values = try instances.map(keyPath.encode)
        guard let path = valuesToPropertyPath[values] else {
            throw ReflectionError.keyPathNotFound(T.self)
        }
        keyPathToPropertyPath[keyPath.cacheKey] = path
        return path
    }
    
    var rootProperties: [String] {
        [String](Set(valuesToPropertyPath.values.map(\.[0])))
    }
}

private var instanceCache = [ObjectIdentifier: Any]()

extension KeyPathMapper {
    static func forType(_ type: T.Type) throws -> KeyPathMapper<T> {
        let typeId = ObjectIdentifier(type)
        if let instance = instanceCache[typeId] {
            guard let instance = instance as? KeyPathMapper<T> else {
                throw SwiftDBError.unexpected(message: "cached collection has wrong type")
            }
            return instance
        }
        let instance = try KeyPathMapper<T>(type)
        instanceCache[typeId] = instance
        return instance
    }
}

/// A KeyPath with the value type erased, but constrained to Codable values
struct PartialCodableKeyPath<Row: Codable>: Equatable {
    let encode: (Row) throws -> Encoded
    let cacheKey: AnyKeyPath
    
    init<V: Encodable>(_ keyPath: KeyPath<Row, V>) {
        self.encode = { try Encoded($0[keyPath: keyPath]) }
        self.cacheKey = keyPath
    }
    
    static func == (lhs: PartialCodableKeyPath<Row>, rhs: PartialCodableKeyPath<Row>) -> Bool {
        return lhs.cacheKey == rhs.cacheKey
    }
    
    func nameExpression(operation: String) throws -> String {
        let mapper = try KeyPathMapper.forType(Row.self)
        let path = try mapper.propertyPath(for: self)
        guard path.count == 1 else {
            let pathString = path.joined(separator: ".")
            throw SwiftDBError.notImplemented(feature: "\(operation) by nested KeyPaths (\\.\(pathString))")
        }
        return SQL.quoteName(path[0])
    }
}
