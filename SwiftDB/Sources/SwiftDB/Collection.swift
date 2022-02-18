///
public class Collection<Row: Codable> {
    private let connection: Connection
    private let mapper: KeyPathMapper<Row>
    private let columns: [String]
    private let table: String
    private let indices: [Index]
    
    internal init(_ type: Row.Type, _ connection: Connection, _ options: [Option] = []) throws {
        self.connection = connection
        self.mapper = try KeyPathMapper(type)
        self.columns = mapper.rootProperties
        
        var table = String(describing: Row.self)
        var indices = [Index]()
        var nonUniqueId = false
        for option in options {
            switch option.kind {
            case .tableName(let name):
                table = name
            case .index(let getEncodedValue, let keyPath, let unique):
                indices.append(Index(
                    [
                        Index.Part(
                            try mapper.propertyPath(for: getEncodedValue, cacheKey: keyPath),
                            .ascending
                        )
                    ],
                    unique: unique
                ))
            case .nonUniqueId: nonUniqueId = true
            }
        }
        if !nonUniqueId && columns.contains("id") {
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
            return Option(kind: .index(mapper(keyPath), keyPath, false))
        }
        
        /// Add a unique index to a property
        public static func unique<V: Codable>(_ keyPath: KeyPath<Row, V>) -> Option {
            return Option(kind: .index(mapper(keyPath), keyPath, true))
        }
        
        /// Disable the default behaviour of adding a unique index to any property called "id"
        public static var nonUniqueId: Option {
            Option(kind: .nonUniqueId)
        }
        
        private static func mapper<V: Codable>(_ keyPath: KeyPath<Row, V>) -> (Row) throws -> Encoded {
            return { try Encoded(encoding: $0[keyPath: keyPath]) }
        }
        
        enum Kind {
            case tableName(String)
            case index((Row) throws -> Encoded, AnyKeyPath, Bool)
            case nonUniqueId
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
    
    public func select() -> SelectBuilder {
        return SelectBuilder(self)
    }
    
    public class SelectBuilder {
        private let collection: Collection<Row>
        
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
        
        private func prepare() throws -> Statement {
            let sql = SQL()
                .select()
                .quotedNames(collection.columns)
                .from(collection.table)
                .text
            return try collection.connection.prepare(sql: sql)
        }
    }
}
