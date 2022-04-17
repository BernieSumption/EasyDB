/// A collection of Codable objects, backed by an SQLite table
///
/// `Collection` is the main interface to data in EasyDB, handling reading and writing data as well as
/// migrating the underlying table to fit `Row`
public class Collection<Row: Codable>: Filterable, DefaultCollations {
    public let tableName: String

    let database: EasyDB
    let columns: [String]
    let mapper: KeyPathMapper<Row>
    let defaultCollations: [String: Collation]

    private let indices: [IndexSpec]

    internal init(
        _ type: Row.Type,
        _ database: EasyDB,
        idProperty: PartialCodableKeyPath<Row>?
    ) throws {
        self.database = database
        self.mapper = try KeyPathMapper.forType(type)
        self.columns = mapper.rootProperties
        self.tableName = defaultTableName(for: Row.self)

        if columns.count == 0 {
            throw EasyDBError.misuse(message: "Can't create a collection of \"\(Row.self)\" - collection types must be structs with at least one property")
        }

        let metadata = try MultifariousDecoder.metadata(for: type)

        let idPropertyName = try idProperty.map({ try $0.requireSingleName() })

        var defaultCollations = [String: Collation]()
        for property in mapper.rootProperties {
            let isId = property == idPropertyName
            defaultCollations[property] = try metadata.getCombinedConfig(property, isId: isId).collation
        }
        self.defaultCollations = defaultCollations

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
    }

    struct Config: Equatable {
        var tableName: String?
        var indices = [IndexSpec]()
    }

    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This defaults to `false`
    public func migrate(dropColumns: Bool = false) throws {
        let migration = SchemaMigration(connection: try database.getConnection())
        try migration.migrateColumns(table: tableName, columns: columns)
        try migration.migrateIndices(table: tableName, indices: indices)
    }

    /// Insert one row into the collection
    ///
    /// - Parameters:
    ///   - row: the row to insert
    ///   - onConflict: What to do when the row violates a uniqueness constraint:
    ///     - `.abort`:  throw an error
    ///     - `.ignore`: make no changes to the existing row
    ///     - `.update`: replace the existing row with the new one
    public func insert(_ row: Row, onConflict: OnConflict? = nil) throws {
        let sql = getInsertSQL(onConflict: onConflict)
        try database.getConnection().execute(sql: sql, namedParameters: row)
    }

    /// Insert many rows into the collection, using a transaction so that if any row can not
    /// be inserted due to a uniqueness constraint, no rows will be inserted
    ///
    /// - Parameters:
    ///   - rows: the rows to insert
    ///   - onConflict: What to do when one of the rows violates a uniqueness constraint:
    ///     - `.abort`:  prevent all rows from being inserted and throw an error
    ///     - `.ignore`: allow all non-conflicting rows to be inserted while ignoring conflicting rows
    ///     - `.update`: replace the existing row with the new one
    public func insert(_ rows: [Row], onConflict: OnConflict? = nil) throws {
        guard rows.count > 0 else {
            return
        }
        let sql = getInsertSQL(onConflict: onConflict)
        try database.inAccessQueue {
            let connection = try database.getConnection()
            do {
                let statement = try connection.notThreadSafe_prepare(sql: sql)
                try connection.execute(sql: "BEGIN TRANSACTION")
                for row in rows {
                    try statement.clearBoundParameters()
                    try StatementEncoder.encode(row, into: statement)
                    _ = try statement.step()
                    statement.reset()
                }
                try connection.execute(sql: "COMMIT TRANSACTION")
            } catch {
                // don't throw an error if the rollback fails, because we want to see the
                // error that actually caused the statement to fail
                try? connection.execute(sql: "ROLLBACK TRANSACTION")
                throw error
            }
        }
    }

    /// Equivalent to `insert(row, onConflict: .replace)`
    public func save(_ row: Row) throws {
        try insert(row, onConflict: .replace)
    }

    /// Equivalent to `insert(rows, onConflict: .replace)`
    public func save(_ rows: [Row]) throws {
        try insert(rows, onConflict: .replace)
    }

    private func getInsertSQL(onConflict: OnConflict?) -> String {
        return SQL()
            .insertInto(tableName, columns: columns, onConflict: onConflict)
            .values()
            .bracketed(namedParameters: columns)
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
}

/// What to do during an insert operation if inserting the entity would violate a uniqueness constraint 
public enum OnConflict {
    /// Throw an error and abort the current transaction
    case abort
    /// Silently ignore rows that can't be inserted
    case ignore
    /// Replace conflicting rows with the new data provided
    case replace
}

protocol DefaultCollations {
    func defaultCollation<T: Codable>(for property: PartialCodableKeyPath<T>) throws -> Collation
}

public protocol CustomTableName {
    static var tableName: String { get }
}

func defaultTableName<T>(for type: T.Type) -> String {
    if let custom = type as? CustomTableName.Type {
        return custom.tableName
    }
    return String(describing: type)
}
