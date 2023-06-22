import Foundation

/// Configure access to an EasyDB database. Most reading and writing of data is done on the `Collection`
/// objects returned by `collection(RecordType.self)`
public class EasyDB {
    let path: String

    private let autoMigrate: Bool
    private let autoDropColumns: Bool

    private var collections = [ObjectIdentifier: Any]()
    private let collectionsSemaphore = DispatchSemaphore(value: 1)

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
        case .path(let path):
            self.path = path
        }
        self.autoMigrate = autoMigrate
        self.autoDropColumns = autoDropColumns
        liveEasyDBInstances += 1
    }

    deinit {
        collections.removeAll()
        connectionManager = ConnectionManager()
        liveEasyDBInstances -= 1
    }

    public enum Location: ExpressibleByStringLiteral, Equatable {
        case path(String)

        public init(stringLiteral path: String) {
            self = .path(path)
        }
    }

    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added
    public func collection<T: Record>(_ type: T.Type) throws -> Collection<T> {
        collectionsSemaphore.wait()
        defer {
            collectionsSemaphore.signal()
        }
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

    /// Execute an SQL statement. If the statement has results, they will be ignored
    public func execute(_ sqlFragment: SQLFragment<NoProperties>) throws {
        try withConnection(write: true, transaction: false) { connection in
            let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil, registerCollation: connection.registerCollation)
            try connection.execute(sql: sql)
        }
    }

    /// Execute an SQL statement and return the results as an instance of `T`. `T` can be any codable type, see
    /// [selecting into custom result types](https://github.com/BernieSumption/EasyDB#selecting-into-custom-result-types)
    public func execute<Result: Codable>(_ resultType: Result.Type, _ sqlFragment: SQLFragment<NoProperties>) throws -> Result {
        return try withConnection(write: true, transaction: false) { connection in
            let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil, registerCollation: connection.registerCollation)
            let parameters = try sqlFragment.parameters()
            return try connection.execute(resultType, sql: sql, parameters: parameters)
        }
    }

    /// Execute a block of code in a transaction using the single global write connection. The calling
    /// thread will block until the write connection is available.
    ///
    /// Code in the block can make any call to the EasyDB API e.g. `database.execute("INSERT INTO ...")`
    /// or `collection.all().update(...)`.
    ///
    /// The transaction is rolled back if the block throws an error, otherwise it is committed.
    ///
    /// Transactions can be nested - code in the block can call `write` or `read`, which behave identically
    /// and create a nested write transaction.  When several transactions are nested, changes are not visible
    /// outside the transaction until the outermost transaction block completed.
    public func write<T>(block: () throws -> T) throws -> T {
        return try withConnection(write: true, transaction: true) { _ in
            return try block()
        }
    }

    /// Execute a block of code in a transaction using a read-only connection. Multiple threads can
    /// read simultaneously.
    ///
    /// Code in the block can make any call to the EasyDB read API e.g. `database.execute("SELECT ...")`
    /// (provided that the SQL doesn't modify data) or `collection.all().fetchMany()`. Any use of
    /// writing methods will result in an exception being thrown.
    ///
    /// The transaction is rolled back if the block throws an error, otherwise it is committed
    ///
    /// Transactions can be nested - code in the block can call `read` to begin a nested transaction. When several
    /// transactions are nested, changes are not visible outside the transaction until the outermost transaction
    /// block completed.
    public func read<T>(block: () throws -> T) throws -> T {
        return try withConnection(write: false, transaction: true) { _ in
            return try block()
        }
    }

    @TaskLocal static var currentConnection: Connection?

    func withConnection<T>(write: Bool = false, transaction: Bool = false, block: (_:Connection) throws -> T) throws -> T {
        guard let current = EasyDB.currentConnection else {
            let connection = try connectionManager.acquireConnection(database: self, write: write)
            defer {
                connectionManager.releaseConnection(connection)
            }
            return try EasyDB.$currentConnection.withValue(connection) {
                try withConnection(write: write, transaction: transaction, block: block)
            }
        }
        if !transaction {
            return try block(current)
        }
        try current.execute(sql: "SAVEPOINT withConnection")
        do {
            let result = try block(current)
            try current.execute(sql: "RELEASE withConnection")
            return result
        } catch {
            try current.execute(sql: "ROLLBACK TO withConnection")
            try current.execute(sql: "RELEASE withConnection")
            throw error
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

var liveEasyDBInstances = 0
