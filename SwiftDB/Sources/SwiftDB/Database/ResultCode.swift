import Foundation
import SQLite3

enum ResultCode: CInt, Error, CustomStringConvertible {
    case SQLITE_OK           = 0
    case SQLITE_ERROR        = 1
    case SQLITE_INTERNAL     = 2
    case SQLITE_PERM         = 3
    case SQLITE_ABORT        = 4
    case SQLITE_BUSY         = 5
    case SQLITE_LOCKED       = 6
    case SQLITE_NOMEM        = 7
    case SQLITE_READONLY     = 8
    case SQLITE_INTERRUPT    = 9
    case SQLITE_IOERR        = 10
    case SQLITE_CORRUPT      = 11
    case SQLITE_NOTFOUND     = 12
    case SQLITE_FULL         = 13
    case SQLITE_CANTOPEN     = 14
    case SQLITE_PROTOCOL     = 15
    case SQLITE_EMPTY        = 16
    case SQLITE_SCHEMA       = 17
    case SQLITE_TOOBIG       = 18
    case SQLITE_CONSTRAINT   = 19
    case SQLITE_MISMATCH     = 20
    case SQLITE_MISUSE       = 21
    case SQLITE_NOLFS        = 22
    case SQLITE_AUTH         = 23
    case SQLITE_FORMAT       = 24
    case SQLITE_RANGE        = 25
    case SQLITE_NOTADB       = 26
    case SQLITE_NOTICE       = 27
    case SQLITE_WARNING      = 28
    case SQLITE_ROW          = 100
    case SQLITE_DONE         = 101
    
    public var description: String {
        let message = String(cString: sqlite3_errstr(rawValue))
        return "\(rawValue) (\(message))"
    }
}
