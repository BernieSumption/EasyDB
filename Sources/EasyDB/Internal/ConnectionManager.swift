import Foundation

/// Manages a single write connection and pool of read connections, concurrently accessed 
struct ConnectionManager {
    var writeConnection: Connection?

    mutating func getConnection(database: EasyDB, write: Bool) throws -> Connection {
        // TODO read connection pool
//        if write {
            if let connection = writeConnection {
                return connection
            }
            let connection = try Connection(database, write: write)
            writeConnection = connection
            return connection
//        } else {
//            throw EasyDBError.notImplemented(feature: "read-only connections")
//        }
    }
}
