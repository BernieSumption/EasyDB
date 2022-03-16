
/// A collection of Codable objects, backed by an SQLite table
///
/// `Collection` is the main interface to data in SwiftDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Codable>: Filterable {
    let connection: Connection
    let columns: [String]
    let table: String
    let mapper: KeyPathMapper<Row>
    
    private let indices: [Index]
    
    internal init(_ type: Row.Type, _ connection: Connection, _ options: [Option], identifiable: Bool) throws {
        self.connection = connection
        self.mapper = try KeyPathMapper(type)
        self.columns = mapper.rootProperties
        
        var table = String(describing: Row.self)
        var indices = [Index]()
        var noUniqueId = false
        for option in options {
            switch option.kind {
            case .tableName(let name):
                table = name
            case .index(let keyPath, let unique):
                let propertyPath = try mapper.propertyPath(for: keyPath)
                indices.append(
                    Index(
                        [Index.Part(propertyPath, .ascending)],
                        unique: unique
                    ))
            case .noUniqueId:
                noUniqueId = true
            }
        }
        if identifiable && !noUniqueId {
            indices.append(Index([Index.Part(["id"], .ascending)], unique: true))
        }
        self.table = table
        self.indices = indices
    }
    
    public struct Option {
        let kind: Kind
        
        /// Customise the table name. The default is the name of the collection `Row` type
        public static func tableName(_ name: String) -> Option {
            return Option(kind: .tableName(name))
        }
        
        /// Add a non-unique index to a property
        public static func index<V: Codable>(_ keyPath: KeyPath<Row, V>) -> Option {
            return Option(kind: .index(PartialCodableKeyPath(keyPath), false))
        }
        
        /// Add a unique index to a property
        public static func unique<V: Codable>(_ keyPath: KeyPath<Row, V>) -> Option {
            return Option(kind: .index(PartialCodableKeyPath(keyPath), true))
        }
        
        /// Disable the default behaviour of creating a unique index on `\.id`  types conforming to `Identifiable`
        public static var noUniqueId: Option {
            Option(kind: .noUniqueId)
        }
        
        enum Kind {
            case tableName(String)
            case index(PartialCodableKeyPath<Row>, Bool)
            case noUniqueId
        }
    }
    
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: connection)
        try migration.migrateColumns(table: table, columns: columns)
        try migration.migrateIndices(table: table, indices: indices)
    }
    
    public func insert(_ row: Row) throws {
        let statement = try getInsertStatement()
        try StatementEncoder.encode(row, into: statement)
        var _ = try statement.step()
    }
    
    public func insert(_ rows: [Row]) throws {
        try rows.forEach(insert)
    }
    
    public func execute(sql: String) throws {
        let statement = try connection.prepare(sql: sql)
        let _ = try statement.step()
    }
    
    public func execute<T: Codable>(_ resultType: T.Type, sql: String) throws -> T {
        let statement = try connection.prepare(sql: sql)
        let _ = try statement.step()
        return try StatementDecoder.decode(resultType, from: statement)
    }
    
    private var insertStatement: Statement?
    private func getInsertStatement() throws -> Statement {
        if let statement = insertStatement {
            try statement.reset()
            return statement
        }
        let sql = SQL()
            .insertInto(table, columns: columns)
            .values()
            .bracketed(namedParameters: columns)
            .text
        let statement = try connection.prepare(sql: sql)
        insertStatement = statement
        return statement
    }
    
    public func all() -> QueryBuilder<Row> {
        return QueryBuilder(self)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        return QueryBuilder(self).filter(sqlFragment)
    }
    
    // TODO: can I remove this?
    public func propertyName<V: Codable>(for keyPath: KeyPath<Row, V>) throws -> String {
        let path = try mapper.propertyPath(for: keyPath)
        guard path.count == 1 else {
            throw SwiftDBError.notImplemented(feature: #"filtering by nested KeyPaths e.g. \.foo.bar"#)
        }
        return path[0]
    }
}

public struct QueryBuilder<Row: Codable>: Filterable {

    private let collection: Collection<Row>
    
    private var filters = [SQLFragment<Row>]()
    
    internal init(_ collection: Collection<Row>) {
        self.collection = collection
    }
    
    public func fetchOne() throws -> Row? {
        let rows = try StatementDecoder.decode([Row].self, from: prepare(), maxRows: 1)
        return rows.first
    }
    
    public func fetchMany() throws -> [Row] {
        return try StatementDecoder.decode([Row].self, from: prepare())
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        var copy = self
        copy.filters.append(sqlFragment)
        return copy
    }
    
    public func propertyName<V: Codable>(for keyPath: KeyPath<Row, V>) throws -> String {
        return try collection.propertyName(for: keyPath)
    }
    
    private func prepare() throws -> Statement {
        var parameters = [DatabaseValue]()
        var sql = SQL()
            .select()
            .quotedNames(collection.columns)
            .from(collection.table)
        
        if filters.count > 0 {
            sql = sql
                .raw("WHERE")
                .raw(
                    try filters
                        .map({ try $0.sql(mapper: collection.mapper) })
                        .joined(separator: " AND ")
                )
            
            for filter in filters {
                parameters += try filter.parameters()
            }
        }
            
        let statement = try collection.connection.prepare(sql: sql.text)
        for (index, parameter) in parameters.enumerated() {
            try statement.bind(parameter, to: index + 1)
        }
        return statement
    }
}

public protocol Filterable {
    associatedtype Row: Codable
    
    // TODO: can I remove this?
    /// Given a key path, return the property name, e.g. `propertyName(\.foo)` will return `"foo"`
    func propertyName<V: Codable>(for keyPath: KeyPath<Row, V>) throws -> String
    
    
    /// Add an SQL filter using string interpolation to provide parameters. String interpolation is used to
    /// provide parameters safely (i.e. without the possibility of SQL injection). This low-level method is
    /// useful to construct complex SQL filters e.g. by invoking SQLite functions.
    ///
    /// For example `filter("replace(foo, '-', '') = \(myString)")` will append
    /// `WHERE replace(foo, '-', '') = ?` to the SQL query and bind `myString` as a parameter
    func filter(_ sqlFragment: SQLFragment<Row>) throws -> QueryBuilder<Row>
}


extension Filterable {
    /// Select records where `property == value`.
    ///
    /// This uses the SQL `IS` operator which has the same semantics as Swift's `==` when comparing null values
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, is value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) IS \(value)")
    }

    /// Select records where `property != value`.
    ///
    /// This uses the SQL `IS NOT` operator which has the same semantics as Swift's `!=` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNot value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) IS NOT \(value)")
    }

    /// Select records where `property > value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThan value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) > \(value)")
    }

    /// Select records where `property < value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThan value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) < \(value)")
    }

    /// Select records where `property >= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThanOrEqualTo value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) >= \(value)")
    }

    /// Select records where `property <= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThanOrEqualTo value: V) throws -> QueryBuilder<Row> {
        return try filter("\(property) <= \(value)")
    }

    /// Select records where `property IS NULL` (if `isNull` is `true`) or `property IS NOT NULL` otherwise
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool) throws -> QueryBuilder<Row> {
        return try filter(isNull ? "\(property) IS NULL" : "\(property) IS NOT NULL")
    }

    /// Select records where `property LIKE value`
    public func filter(_ property: KeyPath<Row, String>, like: String) throws -> QueryBuilder<Row> {
        return try filter("\(property) LIKE \(like)")
    }

    /// Select records where `property NOT LIKE value`
    public func filter(_ property: KeyPath<Row, String>, notLike: String) throws -> QueryBuilder<Row> {
        return try filter("\(property) NOT LIKE \(notLike)")
    }
}

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
    
    func sql(mapper: KeyPathMapper<Row>) throws -> String {
        return try parts.compactMap { part in
            switch part {
            case .literal(let string):
                return string
            case .property(let keyPath):
                let path = try mapper.propertyPath(for: keyPath)
                guard path.count == 1 else {
                    throw SwiftDBError.notImplemented(feature: #"filtering by nested KeyPaths e.g. \.foo.bar"#)
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
