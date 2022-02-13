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
            }
        }
        self.table = table
        self.indices = indices
    }
    
    public struct Option {
        let kind: Kind
        
        public static func tableName(_ name: String) -> Option {
            return Option(kind: .tableName(name))
        }
        
        public static func index<V: Codable>(_ keyPath: KeyPath<Row, V>) -> Option {
            return Option(kind: .index(mapper(keyPath), keyPath, false))
        }
        
        public static func unique<V: Codable>(_ keyPath: KeyPath<Row, V>) -> Option {
            return Option(kind: .index(mapper(keyPath), keyPath, true))
        }
        
        private static func mapper<V: Codable>(_ keyPath: KeyPath<Row, V>) -> (Row) throws -> Encoded {
            return { try Encoded(encoding: $0[keyPath: keyPath]) }
        }
        
        enum Kind {
            case tableName(String)
            case index((Row) throws -> Encoded, AnyKeyPath, Bool)
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
        try StatementEncoder().encode(row, into: statement)
        var _ = try statement.step()
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
            let sql = SQL()
                .select()
                .quotedNames(collection.columns)
                .from(collection.table)
                .text
            let statement = try collection.connection.prepare(sql: sql)
            // TODO: should only query the first
            let rows = try StatementDecoder().decode([Row].self, from: statement)
            return rows.first
        }
        
        public func fetchMany() throws -> [Row] {
            let sql = SQL()
                .select()
                .quotedNames(collection.columns)
                .from(collection.table)
                .text
            let statement = try collection.connection.prepare(sql: sql)
            return try StatementDecoder().decode([Row].self, from: statement)
        }
    }
}
