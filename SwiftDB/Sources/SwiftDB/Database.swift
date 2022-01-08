import Foundation

public class Database {
    private let path: String
    private let options: Options
    private var migratedCollections = Set<ObjectIdentifier>()
    
    public init(path: String, options: Options = Options.standard) {
        self.path = path
        self.options = options
    }
    
    public func collection<T: Codable>(_ type: T.Type) throws -> Collection<T> {
        if options.autoMigrate {
            self.migrate(type, dropColumns: options.autoDropColumns)
        }
        return Collection(type, self)
    }
    
    /// Create the table if required, and add missing columns
    ///
    /// - Parameter dropColumns: Remove unused columns. This frees up disk space, but is irreversible.
    public func migrate<T: Codable>(_ type: T.Type, dropColumns: Bool = false) {
        let typeId = ObjectIdentifier(type)
        if !migratedCollections.contains(typeId) {
            migratedCollections.insert(typeId)
        }
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
