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
        self.table = String(describing: Row.self)
        self.columns = mapper.rootProperties
        
        var indices = [Index]()
        for option in options {
            switch option {
            case .tableName(let name):
                self.table = name
            case .index(let keyPath):
                Next up: need to support keypath lookup for partial keypaths
                indices.append(Index(
                    mapper.propertyPath(for: keyPath),
                    unique: false
                ))
            case .unique(let keyPath):
                indices.append(Index(
                    mapper.propertyPath(for: keyPath),
                    unique: true
                ))
            }
        }
    }
    
    public enum Option {
        case tableName(String)
        case index(PartialKeyPath<Row>)
        case unique(PartialKeyPath<Row>)
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: connection)
        try migration.ensureTableExists(table: table, columns: columns)
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

