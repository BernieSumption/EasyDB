public struct SQLFragment<Row: Codable>: ExpressibleByStringInterpolation {
    private var parts = [Part]()

    enum Part {
        case literal(String)
        case property(PartialCodableKeyPath<Row>)
        case parameter(() throws -> DatabaseValue)
        case collation(Collation)
    }

    init() {}

    public init(stringLiteral value: String) {
        parts.append(.literal(value))
    }

    public init(stringInterpolation: StringInterpolation) {
        parts = stringInterpolation.parts
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        var parts = [Part]()

        public init(literalCapacity: Int, interpolationCount: Int) {}

        init() {}

        public mutating func appendLiteral(_ literal: String) {
            parts.append(.literal(literal))
        }

        public mutating func appendInterpolation<Value: Codable>(_ value: Value) {
            parts.append(.parameter({ try DatabaseValueEncoder.encode(value) }))
        }

        public mutating func appendInterpolation<Value: Codable>(_ property: KeyPath<Row, Value>) {
            parts.append(.property(PartialCodableKeyPath(property)))
        }

        public mutating func appendInterpolation<Row: Codable>(_ collection: Collection<Row>) {
            parts.append(.literal(SQL.quoteName(collection.tableName)))
        }

        public mutating func appendInterpolation(_ collation: Collation) {
            parts.append(.collation(collation))
        }

        public mutating func appendInterpolation(literal sql: String) {
            parts.append(.literal(sql))
        }

        /// Insert a name such as a table name column name, quoted and escaped to avoid syntax errors if the name
        /// contains special characters
        public mutating func appendInterpolation(name: String) {
            parts.append(.literal(SQL.quoteName(name)))
        }

        /// Insert a literal SQL string that is directly unmodified into query.
        public mutating func appendInterpolation(raw sql: String) {
            parts.append(.literal(sql))
        }
    }

    func sql(
        collations: DefaultCollations?,
        overrideCollation: Collation?,
        registerCollation: (Collation) throws -> Void
    ) throws -> String {
        return try parts.compactMap { part -> String? in
            switch part {
            case .literal(let string):
                return string
            case .property(let keyPath):
                var result = SQL.quoteName(try keyPath.requireSingleName())
                if let collation = try overrideCollation ?? collations?.defaultCollation(for: keyPath) {
                    result += " COLLATE "
                    result += SQL.quoteName(collation.name)
                }
                return result
            case .parameter:
                return "?"
            case .collation(let collation):
                try registerCollation(collation)
                return SQL.quoteName(collation.name)
            }
        }
        .joined(separator: "")
    }

    /// Get parameters, passing a handler to register collations. The handler isn't strictly necessary to get parameters, but
    /// it's easy to forget to register collations wherever the API accepts an SQLFragment, and this API makes it harder to forget
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
