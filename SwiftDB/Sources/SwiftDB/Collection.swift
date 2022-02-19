
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
    
    public func filter(sql: String) -> QueryBuilder<Row> {
        return filter(sql: sql, parameters: [])
    }
    
    public func filter(sql: String, parameters: [DatabaseValue] = []) -> QueryBuilder<Row> {
        return QueryBuilder(self).filter(sql: sql, parameters: parameters)
    }
    
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
    
    private var filters = [SQLPart]()
    
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
    
    public func filter(sql: String) -> QueryBuilder<Row> {
        return filter(sql: sql, parameters: [])
    }
    
    public func filter(sql: String, parameters: [DatabaseValue] = []) -> QueryBuilder<Row> {
        var copy = self
        copy.filters.append(SQLPart(sql: sql, parameters: parameters))
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
                .raw(filters.map(\.sql).joined(separator: " AND "))
            
            for filter in filters {
                parameters += filter.parameters
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
    
    /// Given a key path, return the property name, e.g. `propertyName(\.foo)` will return `"foo"`
    func propertyName<V: Codable>(for keyPath: KeyPath<Row, V>) throws -> String
    
    func filter(sql: String) -> QueryBuilder<Row>
    func filter(sql: String, parameters: [DatabaseValue]) -> QueryBuilder<Row>
}
//=, <>, <, <=, >, >=, IS, IS NOT


struct SQLPart {
    let sql: String
    let parameters: [DatabaseValue]
}

extension Filterable {
    public func filter<V: Codable, P: Codable>(_ property: KeyPath<Row, V>, template: String, parameters: [P]) throws -> QueryBuilder<Row> {
        let quotedName = SQL.quoteName(try propertyName(for: property))
        let sql = template.replacingOccurrences(of: "{}", with: quotedName)
        
        return filter(
            sql: sql,
            parameters: try DatabaseValueEncoder.encodeAll(parameters))
    }
    
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, template: String) throws -> QueryBuilder<Row> {
        let quotedName = SQL.quoteName(try propertyName(for: property))
        let sql = template.replacingOccurrences(of: "{}", with: quotedName)
        return filter(sql: sql, parameters: [])
    }
    
    /// Filter by basic comparison operators, e.g. `filter(\.property, <, 7)` is equivalent to SQL `WHERE property < 7`
    ///
    /// - Throws an error if `op` is not one of `==`, `!=`, `<`, `<=`, `>` or `>=`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, _ op: (Int, Int) -> Bool, _ value: V) throws -> QueryBuilder<Row> {
        guard let binOp = operators[[1, 2, 3].filter({ op($0, 2) })] else {
            throw SwiftDBError.misuse(message: "Invalid operator - only ==, !=, <, <=, > and >= are supported")
        }
        return try filter(property, template: "{} \(binOp) ?", parameters: [value])
    }
    
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool) throws -> QueryBuilder<Row> {
        return try filter(property, template: isNull ? "{} IS NULL" : "{} IS NOT NULL")
    }
    
    public func filter(_ property: KeyPath<Row, String>, like: String) throws -> QueryBuilder<Row> {
        return try filter(property, template: "{} LIKE ?", parameters: [like])
    }
    
    public func filter(_ property: KeyPath<Row, String>, notLike: String) throws -> QueryBuilder<Row> {
        return try filter(property, template: "{} NOT LIKE ?", parameters: [notLike])
    }
}

private let operators = [
    [2]: "=",
    [1, 3]: "<>",
    [1]: "<",
    [1, 2]: "<=",
    [3]: ">",
    [2, 3]: ">="
]
