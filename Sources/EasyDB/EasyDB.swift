import Foundation

/// Configure access to an EasyDB database. Most reading and writing of data is done on the `Collection`
/// objects returned by `collection(RecordType.self)`
public class EasyDB {
    let path: String

    private let autoMigrate: Bool
    private let autoDropColumns: Bool

    private var collections = [ObjectIdentifier: Any]()

    // TODO: remove these 2
    private let collectionCreateQueue = DispatchQueue(label: "EasyDB.collectionCreateQueue")
    private let accessQueue = DispatchQueue(label: "EasyDB.databaseAccessQueue")

    private var connectionManager = ConnectionManager()

    /// An `SQLLogger` instance to
    public var logSQL: SQLLogger = .none

    /// Initialise and  configure a database
    ///
    /// - Parameters:
    ///   - location: A string path or `.memory` to create an in-memory database
    ///   - autoMigrate: Whether to automatically create tables and columns for collections.
    ///   - autoDropColumns: Whether to drop columns while running automatic migrations. This defaults to `false` and can be set to `true`
    ///       for the whole database using this option, and overridden for individual collections. Has no effect without `autoMigrate`
    public init(
        _ location: Location,
        autoMigrate: Bool = true,
        autoDropColumns: Bool = false
    ) {
        switch location {
        case .memory:
            self.path = ":memory:"
        case .path(let path):
            self.path = path
        }
        self.autoMigrate = autoMigrate
        self.autoDropColumns = autoDropColumns
    }

    public enum Location: ExpressibleByStringLiteral {
        case memory
        case path(String)

        public init(stringLiteral path: String) {
            self = .path(path)
        }
    }

    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added
    public func collection<T: Record>(_ type: T.Type) throws -> Collection<T> {
        return try collectionCreateQueue.sync {
            let typeId = ObjectIdentifier(type)
            if let collection = collections[typeId] {
                guard let collection = collection as? Collection<T> else {
                    throw EasyDBError.unexpected(message: "cached collection has wrong type")
                }
                return collection
            }
            let collection = try Collection(type, self)
            if autoMigrate {
                try collection.migrate(dropColumns: autoDropColumns)
            }
            collections[typeId] = collection
            return collection
        }
    }

    /// Execute an SQL statement. If the statement has results, they will be ignored
    public func execute(_ sqlFragment: SQLFragment<NoProperties>) throws {
        let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil, registerCollation: registerCollation)
        try getConnection().execute(sql: sql)
    }

    /// Execute an SQL statement and return the results as an instance of `T`. `T` can be any codable type, see
    /// [selecting into custom result types](https://github.com/BernieSumption/EasyDB#selecting-into-custom-result-types)
    public func execute<Result: Codable>(_ resultType: Result.Type, _ sqlFragment: SQLFragment<NoProperties>) throws -> Result {
        let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil, registerCollation: registerCollation)
        let parameters = try sqlFragment.parameters()
        return try getConnection().execute(resultType, sql: sql, parameters: parameters)
    }

    /// Execute a block of code in a transaction, rolling back the transaction if the block throws an error
    public func transaction<T>(block: () throws -> T) rethrows -> T {
        return try inAccessQueue {
            do {
                try execute("BEGIN TRANSACTION")
                let result = try block()
                try execute("COMMIT TRANSACTION")
                return result
            } catch {
                try? execute("ROLLBACK TRANSACTION")
                throw error
            }
        }
    }

    /// Register a custom collation to use in SQL. This is normally not necessary as EasyDB registers
    /// custom collations when they are first used. However if you want to refer to a collation by name
    /// in SQL without first using it in the API, you will need to register it
    public func registerCollation(_ collation: Collation) throws {
        try getConnection().registerCollation(collation)
    }

    @TaskLocal static var currentConnection: Connection?

    func withConnection<T>(write: Bool, transaction: Bool, block: (_:Connection) throws -> T) throws -> T {
        guard let current = EasyDB.currentConnection else {
            let connection = try connectionManager.getConnection(database: self, write: write)
            return try EasyDB.$currentConnection.withValue(connection) {
                try block(connection)
            }
        }
        return try block(current)
    }

    private var cachedConnection: Connection?
    func getConnection() throws -> Connection {
        if let cached = cachedConnection {
            return cached
        }
        let connection = try Connection(self)
        cachedConnection = connection
        return connection
    }

    @TaskLocal static var isInAccessQueue = false

    func inAccessQueue<T>(_ block: () throws -> T) rethrows -> T {
        if EasyDB.isInAccessQueue {
            // Avoid deadlock through reentrance: don't use accessQueue.sync if we're currently being
            // executed by the same dispatch queue
            return try block()
        }
        return try accessQueue.sync {
            return try EasyDB.$isInAccessQueue.withValue(true) {
                return try block()
            }
        }
    }
}

public struct NoProperties: Codable {}

public enum SQLLogger {
    case none
    case print
    case custom((String) -> Void)

    func log(_ message: String) {
        switch self {
        case .print: Swift.print(message)
        case .custom(let callback): callback(message)
        case .none: break
        }
    }

    var enabled: Bool {
        if case .none = self {
            return false
        }
        return true
    }
}
