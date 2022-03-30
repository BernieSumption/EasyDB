import Foundation

/// A `Database` exists mainly to configure access to a database file and to create collections. Most reading and writing
/// of data is done on the `Collection` objects returned by `database.collection(EntityType.self)`
public class Database {
    let path: String
    
    private let autoMigrate: Bool
    private let autoDropColumns: Bool
    private let collectionConfigs: [CollectionConfig]
    
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
    ///   - collections: Any number of `CollectionConfig` values configuring collections on this database. Use the static factory
    ///       function like this: `Database(path: "...", .collection(MyEntity.self, tableName: "t"))`.
    ///
    ///
    ///       It is not necessary to list collections here if there is no need to configure them. A collection that requires no indices or other
    ///       configuration can be omitted and will be created on=demand the first time it is accessed.
    public init(
        path: String,
        autoMigrate: Bool = true,
        autoDropColumns: Bool = false,
        _ collections: CollectionConfig...
    ) {
        self.path = path
        self.autoMigrate = autoMigrate
        self.autoDropColumns = autoDropColumns
        self.collectionConfigs = collections
    }
    
    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added
    public func collection<T: Codable>(_ type: T.Type) throws -> Collection<T> {
        return try collectionCreateQueue.sync {
            let typeId = ObjectIdentifier(type)
            if let collection = collections[typeId] {
                guard let collection = collection as? Collection<T> else {
                    throw SwiftDBError.unexpected(message: "cached collection has wrong type")
                }
                return collection
            }
            let collectionConfig = collectionConfigs.filter { $0.typeId == typeId }
            if collectionConfig.count > 1 {
                throw SwiftDBError.misuse(message: "Collection \(T.self) is configured twice")
            }
            let collection = try Collection(type, self, collectionConfig.first)
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
    
    private var _connection: Connection?
    func getConnection() throws -> Connection {
        if let c = _connection {
            return c
        }
        let c = try Connection(self)
        _connection = c
        return c
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
