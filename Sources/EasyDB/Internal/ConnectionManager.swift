import Foundation

/// Manages a single write connection and pool of read connections, concurrently accessed 
struct ConnectionManager {

    private var writeConnection: Connection?
    private var readConnection: Connection?
    private let writeCreateSemaphore = DispatchSemaphore(value: 1)
    private let writeUseSemaphore = DispatchSemaphore(value: 1)
    private let readCreateSemaphore = DispatchSemaphore(value: 1)
    private let readUseSemaphore = DispatchSemaphore(value: 1)

    mutating func acquireConnection(database: EasyDB, write: Bool) throws -> Connection {
        if write {
            // acquire but do not release the use semaphore - will be released in releaseConnection
            writeUseSemaphore.wait()
            return try getWriteConnection(database)
        } else {
            // acquire but do not release the use semaphore - will be released in releaseConnection
            readUseSemaphore.wait()
            return try getReadConnection(database)
        }
    }

    mutating func releaseConnection(_ connection: Connection) {
        if connection.write {
            writeUseSemaphore.signal()
        } else {
            readUseSemaphore.signal()
        }
    }

    mutating private func getWriteConnection(_ database: EasyDB) throws -> Connection {
        writeCreateSemaphore.wait()
        defer {
            writeCreateSemaphore.signal()
        }
        if let connection = writeConnection {
            return connection
        }
        let connection = try Connection(database, write: true)
        writeConnection = connection
        return connection
    }

    mutating private func getReadConnection(_ database: EasyDB) throws -> Connection {
        // TODO: read connection pool
        readCreateSemaphore.wait()
        defer {
            readCreateSemaphore.signal()
        }
        if writeConnection == nil {
            // ensure that the write connection is created before any read
            // connections, because the write connection auto-creates the
            // database file and read connections require it to exist
            _ = try getWriteConnection(database)
        }
        if let connection = readConnection {
            return connection
        }
        let connection = try Connection(database, write: false)
        readConnection = connection
        return connection
    }
}
