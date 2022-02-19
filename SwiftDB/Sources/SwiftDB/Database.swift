import Foundation

public class Database {
    private let path: String
    private let options: Options
    private var collections = [ObjectIdentifier: Any]()
    
    private let collectionCreateQueue = DispatchQueue(label: "Database.collectionCreateQueue")
    
    public init(path: String, options: Options = Options()) {
        self.path = path
        self.options = options
    }
    
    public func collection<T: Codable & Identifiable>(_ type: T.Type, _ collectionOptions: [Collection<T>.Option] = []) throws -> Collection<T> {
        return try collection(type, collectionOptions, identifiable: true)
    }
    
    public func collection<T: Codable>(_ type: T.Type, _ collectionOptions: [Collection<T>.Option] = []) throws -> Collection<T> {
        return try collection(type, collectionOptions, identifiable: false)
    }
    
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
            if options.autoMigrate {
                try collection.migrate(dropColumns: options.autoDropColumns)
            }
            collections[typeId] = collection
            return collection
        }
    }
    
    public struct Options {
        /// Whether to automatically create missing tables and add missing columns when a `Collection` is created.
        ///
        /// Defaults to `true`. If disabled you can call `migrate(_:dropColumns)` to migrate manually.
        public var autoMigrate = true
        
        /// Whether to drop columns while running automatic migrations. Has no effect without `autoMigrate`
        public var autoDropColumns = false

        /// Print all executed SQL statements as they are executed
        public var logSQL = false
        
        public init(autoMigrate: Bool = true, autoDropColumns: Bool = false, logSQL: Bool = false) {
            self.autoMigrate = autoMigrate
            self.autoDropColumns = autoDropColumns
            self.logSQL = logSQL
        }
    }
    
    private var _connection: Connection?
    private func getConnection() throws -> Connection {
        if let c = _connection {
            return c
        }
        let c = try Connection(path: path, logSQL: options.logSQL)
        _connection = c
        return c
    }
}

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
