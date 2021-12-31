import Foundation
import SQLite3

enum ResultCode: CInt, Error, CustomStringConvertible {
    case OK           = 0
    case ERROR        = 1
    case INTERNAL     = 2
    case PERM         = 3
    case ABORT        = 4
    case BUSY         = 5
    case LOCKED       = 6
    case NOMEM        = 7
    case READONLY     = 8
    case INTERRUPT    = 9
    case IOERR        = 10
    case CORRUPT      = 11
    case NOTFOUND     = 12
    case FULL         = 13
    case CANTOPEN     = 14
    case PROTOCOL     = 15
    case EMPTY        = 16
    case SCHEMA       = 17
    case TOOBIG       = 18
    case CONSTRAINT   = 19
    case MISMATCH     = 20
    case MISUSE       = 21
    case NOLFS        = 22
    case AUTH         = 23
    case FORMAT       = 24
    case RANGE        = 25
    case NOTADB       = 26
    case NOTICE       = 27
    case WARNING      = 28
    case ROW          = 100
    case DONE         = 101
    
    public var description: String {
        let message = String(cString: sqlite3_errstr(rawValue))
        return "\(rawValue) (\(message))"
    }
    
    /// create a ResultCode from a known-good sqlite error code
    init(_ validCode: CInt) throws {
        let primaryCode = validCode & 0xFF
        guard let resultCode = ResultCode(rawValue: primaryCode) else {
            throw SwiftDBError.unexpected("SQLite returned invalid result code \(validCode)")
        }
        self = resultCode
    }
}
