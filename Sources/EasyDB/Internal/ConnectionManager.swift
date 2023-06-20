import Foundation

/// Manages a single write connection and pool of read connections, concurrently accessed 
struct ConnectionManager {

    private var writeConnection: Connection?
    private var readConnection: Connection?
    private let writeSemaphore = DispatchSemaphore(value: 1)
    private let readSemaphore = DispatchSemaphore(value: 1)

    mutating func getConnection(database: EasyDB, write: Bool) throws -> Connection {
        if write {
            return try getWriteConnection(database)
        } else {
            return try getReadConnection(database)
        }
    }

    mutating private func getWriteConnection(_ database: EasyDB) throws -> Connection {
        writeSemaphore.wait()
        defer {
            writeSemaphore.signal()
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
        readSemaphore.wait()
        if writeConnection == nil {
            _ = try getWriteConnection(database)
        }
        defer {
            readSemaphore.signal()
        }
        if let connection = readConnection {
            return connection
        }
        let connection = try Connection(database, write: false)
        readConnection = connection
        return connection
    }

//    mutating func releaseConnections() {
//        readConnection = nil
//        writeConnection = nil
//    }
}
