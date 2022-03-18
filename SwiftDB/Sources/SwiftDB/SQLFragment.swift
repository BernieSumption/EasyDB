
public struct SQLFragment<Row: Codable>: ExpressibleByStringInterpolation {
    var parts = [Part]()
    
    enum Part {
        case literal(String)
        case property(PartialCodableKeyPath<Row>)
        case parameter(DatabaseValue)
    }
    
    init(_ value: String) {
        parts.append(.literal(value))
    }
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public init(stringInterpolation: StringInterpolation) {
        parts = stringInterpolation.parts
    }
    
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts = [Part]()
        
        public init(literalCapacity: Int, interpolationCount: Int) {}
        
        public mutating func appendLiteral(_ literal: String) {
            parts.append(.literal(literal))
        }
        
        public mutating func appendInterpolation<V: Codable>(_ value: V) {
            // TODO: remove force try
            let value = try! DatabaseValueEncoder.encode(value)
            parts.append(.parameter(value))
        }
        
        public mutating func appendInterpolation<V: Codable>(_ property: KeyPath<Row, V>) {
            parts.append(.property(PartialCodableKeyPath(property)))
        }
    }
    
    func sql() throws -> String {
        let mapper = try KeyPathMapper.forType(Row.self)
        return try parts.compactMap { part in
            switch part {
            case .literal(let string):
                return string
            case .property(let keyPath):
                let path = try mapper.propertyPath(for: keyPath)
                guard path.count == 1 else {
                    let pathString = path.joined(separator: ".")
                    throw SwiftDBError.notImplemented(feature: "filtering by nested KeyPaths (\\.\(pathString))")
                }
                return SQL.quoteName(path[0])
            case .parameter:
                return "?"
            }
        }
        .joined(separator: " ")
    }
    
    func parameters() throws -> [DatabaseValue] {
        return parts.compactMap { part -> DatabaseValue? in
            switch part {
            case .parameter(let value):
                return value
            default:
                return nil
            }
        }
    }
}
