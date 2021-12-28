struct KeyPathMapper<T: Codable> {
    private let instances: [T]
    private let valuesToPropertyPath: [[JSON]: [String]]

    init(_ type: T.Type) throws {
        instances = try MultifariousDecoder.instances(for: type)
        let jsonInstances = try instances.map({ try JSON(encoding: $0) })
        guard let first = jsonInstances.first else {
            throw SwiftDBError.unexpected("Multifarious.instances was empty")
        }
        let propertyPaths = first.propertyPaths
        let differing = jsonInstances.first(where: { Set($0.propertyPaths) != Set(propertyPaths) })
        if let differing = differing {
            throw SwiftDBError.unexpected(
                "Multifarious.instances have different structures, \(propertyPaths) and \(differing.propertyPaths)"
            )
        }
        var valuesToPropertyPath = [[JSON]: [String]]()
        for propertyPath in propertyPaths {
            let allValues = try jsonInstances.map { json -> JSON in
                guard let value = json.value(at: propertyPath) else {
                    throw SwiftDBError.unexpected("Instance as no value at \(propertyPath)")
                }
                return value
            }
            if valuesToPropertyPath[allValues] != nil {
                throw SwiftDBError.unexpected("Instances contain multiple \(allValues)")
            }
            valuesToPropertyPath[allValues] = propertyPath
        }
        self.valuesToPropertyPath = valuesToPropertyPath
    }

    func propertyPath<V: Encodable>(for keyPath: KeyPath<T, V>) throws -> [String] {
        let values = try instances.map {
            return try JSON(encoding: $0[keyPath: keyPath])
        }
        guard let path = valuesToPropertyPath[values] else {
            throw ReflectionError.keyPathNotFound(T.self)
        }
        return path
    }
}
