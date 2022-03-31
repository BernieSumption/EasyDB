
public struct SQLFragment<Row: Codable>: ExpressibleByStringInterpolation {
    var parts = [Part]()
    
    enum Part {
        case literal(String)
        case property(PartialCodableKeyPath<Row>)
        case parameter(() throws -> DatabaseValue)
    }
    
    init() {}
    
    public init(stringLiteral value: String) {
        parts.append(.literal(value))
    }
    
    public init(stringInterpolation: StringInterpolation) {
        parts = stringInterpolation.parts
    }
    
    mutating func append(literal: String) {
        parts.append(.literal(literal))
    }
    
    mutating func append<V: Codable>(parameter value: V) {
        parts.append(.parameter({ try DatabaseValueEncoder.encode(value) }))
    }
    
    mutating func append<V: Codable>(property: KeyPath<Row, V>) {
        parts.append(.property(PartialCodableKeyPath(property)))
    }
    
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts = [Part]()
        
        public init(literalCapacity: Int, interpolationCount: Int) {}
        
        public mutating func appendLiteral(_ literal: String) {
            parts.append(.literal(literal))
        }
        
        public mutating func appendInterpolation<V: Codable>(_ value: V) {
            parts.append(.parameter({ try DatabaseValueEncoder.encode(value) }))
        }
        
        public mutating func appendInterpolation<V: Codable>(_ property: KeyPath<Row, V>) {
            parts.append(.property(PartialCodableKeyPath(property)))
        }
    }
    
    func sql(collations: DefaultCollations?, overrideCollation: Collation?) throws -> String {
        return try parts.compactMap { part -> String? in
            switch part {
            case .literal(let string):
                return string
            case .property(let keyPath):
                var result = try keyPath.nameExpression()
                if let collation = overrideCollation ?? collations?.defaultCollation(for: keyPath.cacheKey) {
                    result += " COLLATE "
                    result += SQL.quoteName(collation.name)
                }
                return result
            case .parameter:
                return "?"
            }
        }
        .joined(separator: "")
    }
    
    func parameters() throws -> [DatabaseValue] {
        return try parts.compactMap { part -> DatabaseValue? in
            switch part {
            case .parameter(let value):
                return try value()
            default:
                return nil
            }
        }
    }
}
