import Foundation

public class Database {
    private let path: String
    private var autoMigrate = true
    private var autoDropColumns = false
    public var logSQL = false
    private var collections = [ObjectIdentifier: Any]()
    
    private let collectionCreateQueue = DispatchQueue(label: "Database.collectionCreateQueue")
    
    public init(path: String, options: [Option] = []) {
        self.path = path
        for option in options {
            switch option {
            case .autoMigrate(let value):
                self.autoMigrate = value
            case .autoDropColumns(let value):
                self.autoDropColumns = value
            case .logSQL(let value):
                self.logSQL = value
            }
        }
    }
    
    public func collection<T: Codable & Identifiable>(_ type: T.Type, _ collectionOptions: [Collection<T>.Option] = []) throws -> Collection<T> {
        return try collection(type, collectionOptions, identifiable: true)
    }
    
    public func collection<T: Codable>(_ type: T.Type, _ collectionOptions: [Collection<T>.Option] = []) throws -> Collection<T> {
        return try collection(type, collectionOptions, identifiable: false)
    }
    
    /// Return a collection. Unless automatic migration is disabled for this database, the table will be automatically
    /// created or any missing columns added
    func collection<T: Codable>(_ type: T.Type, _ collectionOptions: [Collection<T>.Option], identifiable: Bool) throws -> Collection<T> {
        return try collectionCreateQueue.sync {
            let typeId = ObjectIdentifier(type)
            if let collection = collections[typeId] {
                guard let collection = collection as? Collection<T> else {
                    throw SwiftDBError.unexpected(message: "cached collection has wrong type")
                }
                return collection
            }
            let collection = try Collection(type, try getConnection(), collectionOptions, identifiable: identifiable)
            if autoMigrate {
                try collection.migrate(dropColumns: autoDropColumns)
            }
            collections[typeId] = collection
            return collection
        }
    }
    
    /// Execute an SQL statement. If the statement has results, they will be ignored
    public func execute(_ sqlFragment: SQLFragment<NoProperties>) throws {
        let statement = try getConnection().prepare(sql: try sqlFragment.sql(propertyCollation: nil))
        let _ = try statement.step()
    }
    
    /// Execute an SQL statement and return the results as an instance of T. T can be any codable type, see the rules
    /// for decoding queries TODO: link to docs for "selecting results into other types"
    public func execute<T: Codable>(_ resultType: T.Type, _ sqlFragment: SQLFragment<NoProperties>) throws -> T {
        let statement = try getConnection().prepare(sql: sqlFragment.sql(propertyCollation: nil))
        try statement.bind(try sqlFragment.parameters())
        return try StatementDecoder.decode(resultType, from: statement)
    }
    
    public enum Option {
        /// Whether to automatically create missing tables and add missing columns when a `Collection` is created.
        ///
        /// Defaults to `true`. If disabled you can call `migrate(_:dropColumns)` to migrate manually.
        case autoMigrate(Bool)
        
        /// Whether to drop columns while running automatic migrations. Defaults to false. Has no effect without `autoMigrate`
        case autoDropColumns(Bool)

        /// Print all executed SQL statements as they are executed. Defaults to false.
        case logSQL(Bool)
    }
    
    private var _connection: Connection?
    private func getConnection() throws -> Connection {
        if let c = _connection {
            return c
        }
        let c = try Connection(path: path, logSQL: logSQL)
        _connection = c
        return c
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
