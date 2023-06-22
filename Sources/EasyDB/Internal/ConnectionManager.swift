import Foundation

/// Manages a single write connection and pool of read connections, concurrently accessed 
struct ConnectionManager {

    let readerCacheSize: UInt

    init(readerCacheSize: UInt) {
        self.readerCacheSize = readerCacheSize
    }

    mutating func acquireConnection(database: EasyDB, write: Bool) throws -> Connection {
        if write {
            return try acquireWriteConnection(database)
        } else {
            return try getOrCreateReadConnection(database)
        }
    }

    mutating func releaseConnection(_ connection: Connection) {
        if connection.write {
            releaseWriteConnection(connection)
        } else {
            releaseReadConnection(connection)
        }
    }

    //
    // SINGLE WRITER IMPLEMENTATION
    //

    private var writeConnection: Connection?
    private let writerManagementSemaphore = DispatchSemaphore(value: 1)
    private let writerUseSemaphore = DispatchSemaphore(value: 1)

    mutating private func acquireWriteConnection(_ database: EasyDB) throws -> Connection {
        let connection = try getOrCreateWriteConnection(database)
        // acquire the use semaphore after the connection is successfully created,
        // to avoid holding a lock if the creation fails.
        writerUseSemaphore.wait()
        return connection
    }

    mutating private func getOrCreateWriteConnection(_ database: EasyDB) throws -> Connection {
        writerManagementSemaphore.wait()
        defer {
            writerManagementSemaphore.signal()
        }
        if let connection = writeConnection {
            return connection
        }
        let connection = try Connection(database, write: true)
        writeConnection = connection
        return connection
    }

    mutating func releaseWriteConnection(_ connection: Connection) {
        writerUseSemaphore.signal()
    }

    //
    // READER POOL IMPLEMENTATION
    //

    private var readerCache = Set<Connection>()
    private let readerManagementSemaphore = DispatchSemaphore(value: 1)

    mutating private func getOrCreateReadConnection(_ database: EasyDB) throws -> Connection {
        readerManagementSemaphore.wait()
        defer {
            readerManagementSemaphore.signal()
        }
        if writeConnection == nil {
            // ensure that the write connection is created before any read
            // connections, because the write connection auto-creates the
            // database file and read connections require it to exist
            _ = try getOrCreateWriteConnection(database)
        }
        if let connection = readerCache.first {
            readerCache.remove(connection)
            return connection
        }
        return try Connection(database, write: false)
    }

    mutating func releaseReadConnection(_ connection: Connection) {
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
