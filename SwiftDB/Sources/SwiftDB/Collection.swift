
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
    
    public func filter<V: Codable>(_ keyPath: KeyPath<Row, V>, eq value: V) throws -> QueryBuilder<Row> {
        return try QueryBuilder(self).filter(keyPath, eq: value)
    }
}

public struct QueryBuilder<Row: Codable>: Filterable {
    private let collection: Collection<Row>
    
    private var filters = [(String, DatabaseValue?)]()
    
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
    
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, eq value: V) throws -> QueryBuilder<Row> {
        return try filter(property, "=", DatabaseValueEncoder.encode(value))
    }
    
    private func filter<V: Codable>(_ property: KeyPath<Row, V>, _ op: String, _ value: DatabaseValue?) throws -> QueryBuilder<Row> {
        let path = try collection.mapper.propertyPath(for: property)
        guard path.count == 1 else {
            throw SwiftDBError.notImplemented(feature: #"filtering by nested KeyPaths e.g. \.foo.bar"#)
        }
        let property = path[0]
        
        var copy = self
        copy.filters.append(("\(property) \(op) ?", value))
        return copy
    }
    
    private func prepare() throws -> Statement {
        var parameters = [DatabaseValue]()
        var sql = SQL()
            .select()
            .quotedNames(collection.columns)
            .from(collection.table)
        
        if filters.count > 0 {
            sql = sql.raw("WHERE")
            for (fragment, value) in filters {
                sql = sql.raw(fragment)
                if let value = value {
                    parameters.append(value)
                }
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
    
    /// Add an equality filter, `filter(\.prop, 5)` being equivalent to SQL `WHERE prop = 5`
    func filter<V: Codable>(_ property: KeyPath<Row, V>, eq: V) throws -> QueryBuilder<Row>
}
