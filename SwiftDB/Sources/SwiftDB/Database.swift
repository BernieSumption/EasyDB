import Foundation

public class Database {
    private let path: String
    private let options: Options
    private var collections = [ObjectIdentifier: Any]()
    
    public init(path: String, options: Options = Options.standard) {
        self.path = path
        self.options = options
    }
    
    public func collection<T: Codable>(_ type: T.Type) throws -> Collection<T> {
        let typeId = ObjectIdentifier(type)
        if let collection = collections[typeId] {
            guard let collection = collection as? Collection<T> else {
                throw SwiftDBError.unexpected(message: "cached collection has wrong type")
            }
            return collection
        }
        let collection = try Collection(type, try getConnection())
        if options.autoMigrate {
            try collection.migrate(dropColumns: options.autoDropColumns)
        }
        collections[typeId] = collection
        return collection
    }
    
    public struct Options {
        /// Whether to automatically create missing tables and add missing columns when a `Collection` is created.
        ///
        /// Defaults to `true`. If disabled you can call `migrate(_:dropColumns)` to migrate manually.
        public var autoMigrate = true
        
        /// Whether to drop columns while running automatic migrations. Has no effect without `autoMigrate`
        public var autoDropColumns = false
        
        public static let standard = Options()
    }
    
    private var _connection: Connection?
    private func getConnection() throws -> Connection {
        if let c = _connection {
            return c
        }
        let c = try Connection(path: path)
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
            .urls(for: .documentDirectory,in: .userDomainMask)[0]
            .appendingPathComponent("swiftdb.sqlite")
            .path
    }
}
