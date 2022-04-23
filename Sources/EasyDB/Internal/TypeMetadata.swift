class TypeMetadata {
    private var propertyConfigs = [String: [PropertyConfig]]()
    private var lastPropertyName: String?
    private var currentPropertyName: String?

    /// Called we start encoding a top-level property on a type
    func startTopLevelProperty(propertyName: String) throws {
        if let currentPropertyName = currentPropertyName {
            throw EasyDBError.unexpected(message: "Can't start encoding \(propertyName), already encoding \(currentPropertyName)")
        }
        currentPropertyName = propertyName
    }

    /// Called we finish encoding a top-level property on a type - i.e. when we have finished the chain of single value
    /// encoding containers that correspond to metadata annotations property wrappers like @Index or @Unique
    func finishTopLevelProperty() {
        if let currentPropertyName = currentPropertyName {
            lastPropertyName = currentPropertyName
        }
        currentPropertyName = nil
    }

    /// Add a config to the current property
    ///
    /// - Throws: `TypeMetadataError.notAtRootLevel` if we're not encoding a root property
    func addPropertyConfig(_ config: PropertyConfig) throws {
        guard let propertyName = currentPropertyName else {
            throw TypeMetadataError.notAtRootLevel
        }
        var configs = propertyConfigs[propertyName] ?? []

        if configs.contains(config) {
            throw TypeMetadataError.duplicate
        }

        configs.append(config)
        propertyConfigs[propertyName] = configs
    }

    func getConfigs(_ propertyName: String) -> [PropertyConfig] {
        return propertyConfigs[propertyName] ?? []
    }

    func getCombinedConfig(_ propertyName: String, isId: Bool) throws -> CombinedPropertyConfig {
        var resultCollation: Collation?
        var resultIndex: CombinedPropertyConfig.IndexKind?

        if let configs = propertyConfigs[propertyName] {
            for config in configs {
                switch config {
                case .collation(let collation):
                    if let resultCollation = resultCollation {
                        throw EasyDBError.misuse(message: "Multiple collations specified for \(propertyName) - \(resultCollation.name) then \(collation.name)")
                    }
                    resultCollation = collation
                case .index(unique: let unique):
                    if unique {
                        resultIndex = .unique
                    } else if resultIndex != .unique {
                        resultIndex = .regular
                    }
                }
            }
        }

        if isId {
            resultIndex = .unique
        }

        return CombinedPropertyConfig(
            collation: resultCollation ?? .string,
            index: resultIndex)
    }

    static let userInfoKey = CodingUserInfoKey(rawValue: String(describing: TypeMetadata.self))!
}

enum TypeMetadataError: Error {
    case notAtRootLevel
    case duplicate

    func message(annotationName: String) -> String {
        switch self {
        case .notAtRootLevel:
            return "configuration property wrapper @\(annotationName) encountered below the top level type"
        case .duplicate:
            return "duplicate configuration property wrapper @\(annotationName) encountered"
        }
    }
}

struct CombinedPropertyConfig: Equatable {
    let collation: Collation
    let index: IndexKind?

    enum IndexKind {
        case unique, regular
    }
}
