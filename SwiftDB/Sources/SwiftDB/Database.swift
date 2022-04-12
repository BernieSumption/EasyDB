import Foundation

/// A `Database` exists mainly to configure access to a database file and to create collections. Most reading and writing
/// of data is done on the `Collection` objects returned by `database.collection(EntityType.self)`
public class Database {
    let path: String

    private let autoMigrate: Bool
    private let autoDropColumns: Bool

    private var collections = [ObjectIdentifier: Any]()

    private let collectionCreateQueue = DispatchQueue(label: "SwiftDB.collectionCreateQueue")
    private let accessQueue = DispatchQueue(label: "SwiftDB.databaseAccessQueue")

    /// An `SQLLogger` instance to
    public var logSQL: SQLLogger = .none

    /// Initialise and  configure a `Database`
    ///
    /// - Parameters:
    ///   - path: A file path to the database file on disk, or `":memory:"` to create an in-memory database
    ///   - autoMigrate: Whether to drop columns while running automatic migrations. This defaults to `false` and can be set to `true`
    ///       for the whole database using this option, and overridden for individual collections. Has no effect without `autoMigrate`
    public init(
        path: String,
        autoMigrate: Bool = true,
        autoDropColumns: Bool = false
    ) {
        self.path = path
        self.autoMigrate = autoMigrate
        self.autoDropColumns = autoDropColumns
    }

    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added.
    public func collection<T: Codable>(_ type: T.Type) throws -> Collection<T> {
        return try collection(type, idProperty: nil)
    }

    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added.
    ///
    /// By default, collections of identifiable types will be given a unique index for the `id` property. This behaviour
    /// can be disabled with the `@NotUnique` configuration property wrapper
    public func collection<T: Codable & Identifiable>(
        _ type: T.Type
    ) throws -> Collection<T> where T.ID: Codable {
        return try collection(type, idProperty: PartialCodableKeyPath(\T.id))
    }

    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added
    func collection<T: Codable>(_ type: T.Type, idProperty: PartialCodableKeyPath<T>?) throws -> Collection<T> {
        return try collectionCreateQueue.sync {
            let typeId = ObjectIdentifier(type)
            if let collection = collections[typeId] {
                guard let collection = collection as? Collection<T> else {
                    throw SwiftDBError.unexpected(message: "cached collection has wrong type")
                }
                return collection
            }
            let collection = try Collection(type, self, idProperty: idProperty)
            if autoMigrate {
                try collection.migrate(dropColumns: autoDropColumns)
            }
            collections[typeId] = collection
            return collection
        }
    }

    /// Execute an SQL statement. If the statement has results, they will be ignored
    public func execute(_ sqlFragment: SQLFragment<NoProperties>) throws {
        let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil)
        try getConnection().execute(sql: sql)
    }

    /// Execute an SQL statement and return the results as an instance of T. T can be any codable type, see the rules
    /// for decoding queries TODO: link to docs for "selecting results into other types"
    public func execute<T: Codable>(_ resultType: T.Type, _ sqlFragment: SQLFragment<NoProperties>) throws -> T {
        let sql = try sqlFragment.sql(collations: nil, overrideCollation: nil)
        let parameters = try sqlFragment.parameters()
        return try getConnection().execute(resultType, sql: sql, parameters: parameters)
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
        if Database.isInAccessQueue {
            // Avoid deadlock through reentrance: don't use accessQueue.sync if we're currently being
            // executed by the same dispatch queue
            return try block()
        }
        return try accessQueue.sync {
            return try Database.$isInAccessQueue.withValue(true) {
                return try block()
            }
        }
    }
}

public struct NoProperties: Codable {}

extension Database {
    /// The standard database - most applications can use this unless they need multiple
    /// databases or want to save the data file somewhere other than `Database.standardPath`
    public static let standard = Database(path: Database.standardPath)

    /// The path of the standard
    public static var standardPath: String {
        return FileManager
            .default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("swiftdb.sqlite")
            .path
    }
}

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
