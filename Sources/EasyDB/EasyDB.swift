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
        EasyDB.liveInstances += 1
    }

    deinit {
        collections.removeAll()
        EasyDB.liveInstances -= 1
    }

    static var liveInstances = 0

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

    /// Execute a block of code in a transaction, rolling back the transaction if the block throws an error
    public func transaction<T>(block: () throws -> T) throws -> T {
        return try withConnection(write: true) { _ in
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

    @TaskLocal static var currentConnection: Connection?

    func withConnection<T>(write: Bool = false, transaction: Bool = false, block: (_:Connection) throws -> T) throws -> T {
        guard let current = EasyDB.currentConnection else {
            let connection = try connectionManager.getConnection(database: self, write: write)
            return try EasyDB.$currentConnection.withValue(connection) {
                try block(connection)
            }
        }
        return try block(current)
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
