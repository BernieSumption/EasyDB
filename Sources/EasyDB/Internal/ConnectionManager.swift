import Foundation

/// Manages a single write connection and pool of read connections, concurrently accessed 
struct ConnectionManager {

    let readerCacheSize: UInt

    init(readerCacheSize: UInt) {
        self.readerCacheSize = readerCacheSize
    }

    /// Get a connection, blocking if necessary until a connection of the appropriate kid is available
    ///
    /// No other threads will be able to use the connection until it is released
    mutating func acquire(database: EasyDB, write: Bool) throws -> Connection {
        if write {
            return try acquireWriter(database)
        } else {
            return try getOrCreateReader(database)
        }
    }

    /// Release a connection - the calling thread must not use the connection after releasing it
    mutating func release(_ connection: Connection) {
        if connection.write {
            releaseWriter(connection)
        } else {
            releaseReader(connection)
        }
    }

    //
    // SINGLE WRITER IMPLEMENTATION
    //

    private var writeConnection: Connection?
    private let writerManagementSemaphore = DispatchSemaphore(value: 1)
    private let writerUseSemaphore = DispatchSemaphore(value: 1)

    mutating private func acquireWriter(_ database: EasyDB) throws -> Connection {
        let connection = try getOrCreateWriter(database)
        // acquire the use semaphore after the connection is successfully created,
        // to avoid holding a lock if the creation fails.
        writerUseSemaphore.wait()
        return connection
    }

    mutating private func getOrCreateWriter(_ database: EasyDB) throws -> Connection {
        writerManagementSemaphore.wait()
        defer {
            writerManagementSemaphore.signal()
        }
        if let connection = writeConnection {
            return connection
        }
        let connection = try Connection(database, write: true, name: "write")
        writeConnection = connection
        return connection
    }

    mutating func releaseWriter(_ connection: Connection) {
        writerUseSemaphore.signal()
    }

    //
    // READER POOL IMPLEMENTATION
    //

    private var readerCache = Set<Connection>()
    private let readerManagementSemaphore = DispatchSemaphore(value: 1)
    private var readerCount = 0

    mutating private func getOrCreateReader(_ database: EasyDB) throws -> Connection {
        readerManagementSemaphore.wait()
        defer {
            readerManagementSemaphore.signal()
        }
        if writeConnection == nil {
            // ensure that the write connection is created before any read
            // connections, because the write connection auto-creates the
            // database file and read connections require it to exist
            _ = try getOrCreateWriter(database)
        }
        if let connection = readerCache.first {
            readerCache.remove(connection)
            return connection
        }
        readerCount += 1
        return try Connection(database, write: false, name: "read#\(readerCount)")
    }

    mutating func releaseReader(_ connection: Connection) {
        readerManagementSemaphore.wait()
        defer {
            readerManagementSemaphore.signal()
        }
        if readerCache.count < readerCacheSize {
            readerCache.insert(connection)
        }
    }
}

private class PooledConnection: Hashable {
    var connection: Connection

    init(connection: Connection) {
        self.connection = connection
    }

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: PooledConnection, rhs: PooledConnection) -> Bool {
        return lhs === rhs
    }
}
