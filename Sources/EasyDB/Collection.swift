/// A collection of records, backed by an SQLite table
///
/// `Collection` is the main interface to data in EasyDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Record>: Filterable, DefaultCollations {
    public let tableName: String

    private weak var database: EasyDB?

    let columns: [String]
    let mapper: KeyPathMapper<Row>
    let defaultCollations: [String: Collation]
    let allDefaultCollations: Set<Collation>

    private let indices: [IndexSpec]
    private let idPropertyName: String

    init(_ type: Row.Type, _ database: EasyDB) throws {
        self.database = database
        self.mapper = try KeyPathMapper.forType(type)
        self.columns = mapper.rootProperties
        self.tableName = Row.tableName

        if columns.count == 0 {
            throw EasyDBError.misuse(message: "Can't create a collection of \"\(Row.self)\" - collection types must be structs with at least one property")
        }

        let metadata = try MultifariousDecoder.metadata(for: type)

        idPropertyName = try PartialCodableKeyPath(\Row.id).requireSingleName()

        var defaultCollations = [String: Collation]()
        for property in mapper.rootProperties {
            let isId = property == idPropertyName
            let collation = try metadata.getCombinedConfig(property, isId: isId).collation
            defaultCollations[property] = collation
        }
        self.defaultCollations = defaultCollations
        self.allDefaultCollations = Set(self.defaultCollations.values)

        var indices = [IndexSpec]()
        for property in mapper.rootProperties {
            let config = try metadata.getCombinedConfig(property, isId: property == idPropertyName)
            if let index = config.index {
                let unique = index == .unique
                let collation = defaultCollations[property] ?? .string
                let index = IndexSpec(
                    [IndexSpec.Part([property], collation: collation)],
                    unique: unique)
                indices.append(index)
            }
        }
        self.indices = indices
        liveCollectionInstances += 1
    }

    deinit {
        liveCollectionInstances -= 1
    }

    struct Config: Equatable {
        var tableName: String?
        var indices = [IndexSpec]()
    }

    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        try getDatabase().withConnection(write: true, transaction: true) { connection in
            connection.registerCollection(self)
            let migration = SchemaMigration(connection: connection)
            try migration.migrateColumns(table: tableName, columns: columns)
            try migration.migrateIndices(table: tableName, indices: indices)
        }
    }

    /// Insert one row into the collection
    public func insert(_ row: Row) throws {
        try insert(row, upsert: false)
    }

    /// Insert many rows into the collection. This operation is atomic: if any row fails to insert e.g. due to a
    /// unique constraint violation, an error will be thrown and no rows will be inserted.
    public func insert(_ rows: [Row]) throws {
        try insert(rows, upsert: false)
    }

    /// Persist a row, replacing any existing row with the same `id`
    public func save(_ row: Row) throws {
        try insert(row, upsert: true)
    }

    /// Persist multiple rows, each row replacing any existing row with the same `id`. This operation is atomic: if any
    /// row fails to insert e.g. due to a unique constraint violation, an error will be thrown and no rows will be saved.
    public func save(_ rows: [Row]) throws {
        try insert(rows, upsert: true)
    }

    func getDatabase() throws -> EasyDB {
        guard let database = self.database else {
            throw EasyDBError.misuse(message: connectionUsedAfterDeinitMessage)
        }
        return database
    }

    private func insert(_ row: Row, upsert: Bool) throws {
        let sql = getInsertSQL(upsert: upsert)

        try getDatabase().withConnection(write: true) { connection in
            connection.registerCollection(self)
            try connection.execute(sql: sql, namedParameters: row)
        }
    }

    private func insert(_ rows: [Row], upsert: Bool) throws {
        guard rows.count > 0 else {
            return
        }
        let sql = getInsertSQL(upsert: upsert)
        try getDatabase().withConnection(write: true, transaction: true) { connection in
            connection.registerCollection(self)
            let statement = try connection.prepare(sql: sql)
            for row in rows {
                try statement.clearBoundParameters()
                try StatementEncoder.encode(row, into: statement)
                _ = try statement.step()
                statement.reset()
            }
        }
    }

    private func getInsertSQL(upsert: Bool) -> String {
        let sql = SQL()
            .insertInto(tableName, columns: columns)
            .values()
            .bracketed(namedParameters: columns)
        if !upsert {
            return sql.text
        }
        return sql
            .raw("ON CONFLICT")
            .bracketed(quotedNames: [idPropertyName])
            .raw("DO UPDATE SET")
            .raw(
                columns
                    .map({"\(SQL.quoteName($0))=:\($0)"})
                    .joined(separator: ", ")
            )
            .text

    }

    public func all() -> QueryBuilder<Row> {
        return QueryBuilder(self)
    }

    public func filter(_ sqlFragment: SQLFragment<Row>, collation: Collation?) -> QueryBuilder<Row> {
        return QueryBuilder(self).filter(sqlFragment, collation: collation)
    }

    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        return filter(sqlFragment, collation: nil)
    }

    func defaultCollation<T: Codable>(for property: PartialCodableKeyPath<T>) throws -> Collation {
        let name = try property.requireSingleName()
        return defaultCollations[name] ?? .string
    }

    let id: UInt64 = {
        collectionIdCounter += 1
        return collectionIdCounter
    }()
}

private var collectionIdCounter: UInt64 = 0

protocol DefaultCollations {
    func defaultCollation<T: Codable>(for property: PartialCodableKeyPath<T>) throws -> Collation
}

var liveCollectionInstances = 0
