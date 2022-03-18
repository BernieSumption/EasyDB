
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
        self.mapper = try KeyPathMapper.forType(type)
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
    
    public struct Option: Equatable {
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
        
        enum Kind: Equatable {
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
                        .map({ try $0.sql() })
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
    
    /// Add an SQL filter using string interpolation to provide parameters. String interpolation is used to
    /// provide parameters safely (i.e. without the possibility of SQL injection). This low-level method is
    /// useful to construct complex SQL filters e.g. by invoking SQLite functions.
    ///
    /// For example `filter("replace(foo, '-', '') = \(myString)")` will append
    /// `WHERE replace(foo, '-', '') = ?` to the SQL query and bind `myString` as a parameter
    func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row>
}


extension Filterable {
    /// Select records where `property == value`.
    ///
    /// This uses the SQL `IS` operator which has the same semantics as Swift's `==` when comparing null values
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, is value: V) -> QueryBuilder<Row> {
        return filter("\(property) IS \(value)")
    }

    /// Select records where `property != value`.
    ///
    /// This uses the SQL `IS NOT` operator which has the same semantics as Swift's `!=` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNot value: V) -> QueryBuilder<Row> {
        return filter("\(property) IS NOT \(value)")
    }

    /// Select records where `property > value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThan value: V) -> QueryBuilder<Row> {
        return filter("\(property) > \(value)")
    }

    /// Select records where `property < value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThan value: V) -> QueryBuilder<Row> {
        return filter("\(property) < \(value)")
    }

    /// Select records where `property >= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThanOrEqualTo value: V) -> QueryBuilder<Row> {
        return filter("\(property) >= \(value)")
    }

    /// Select records where `property <= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThanOrEqualTo value: V) -> QueryBuilder<Row> {
        return filter("\(property) <= \(value)")
    }

    /// Select records where `property IS NULL` (if `isNull` is `true`) or `property IS NOT NULL` otherwise
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool) -> QueryBuilder<Row> {
        return filter(isNull ? "\(property) IS NULL" : "\(property) IS NOT NULL")
    }

    /// Select records where `property LIKE value`
    public func filter(_ property: KeyPath<Row, String>, like: String) -> QueryBuilder<Row> {
        return filter("\(property) LIKE \(like)")
    }

    /// Select records where `property NOT LIKE value`
    public func filter(_ property: KeyPath<Row, String>, notLike: String) -> QueryBuilder<Row> {
        return filter("\(property) NOT LIKE \(notLike)")
    }
}
