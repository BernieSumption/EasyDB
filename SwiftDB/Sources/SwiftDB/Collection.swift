
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
            case .index(let spec):
                let propertyPath = try mapper.propertyPath(for: spec.keyPath)
                indices.append(
                    Index(
                        [Index.Part(propertyPath, collation: spec.collation)],
                        unique: spec.unique))
            case .noUniqueId:
                noUniqueId = true
            }
        }
        if identifiable && !noUniqueId {
            let index = Index([Index.Part(["id"], .ascending)], unique: true)
            indices.append(index)
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
        
        /// Add an index to a property
        public static func index<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            unique: Bool = false,
            name: String? = nil,
            collation: Collation? = nil
        ) -> Option {
            let spec = IndexSpec(
                keyPath: PartialCodableKeyPath(keyPath),
                unique: unique,
                collation: collation
            )
            return Option(kind: .index(spec))
        }
        
        /// A convenience shortcut for adding a unique index to a property  with `.index(... unique:true)`)
        public static func unique<V: Codable>(
            _ keyPath: KeyPath<Row, V>,
            name: String? = nil,
            collation: Collation? = nil
        ) -> Option {
            return index(keyPath, unique: true, name: name, collation: collation)
        }
        
        /// Disable the default behaviour of creating a unique index on `\.id`  types conforming to `Identifiable`
        public static var noUniqueId: Option {
            Option(kind: .noUniqueId)
        }
        
        enum Kind: Equatable {
            case tableName(String)
            case index(IndexSpec)
            case noUniqueId
        }
        
        struct IndexSpec: Equatable {
            let keyPath: PartialCodableKeyPath<Row>
            let unique: Bool
            let collation: Collation?
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
