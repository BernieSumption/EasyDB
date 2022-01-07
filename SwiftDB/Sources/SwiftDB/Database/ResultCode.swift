import Foundation
import CSQLite

private let codeNames: [CInt: String] = [
    0: "SQLITE_OK",
    1: "SQLITE_ERROR",
    2: "SQLITE_INTERNAL",
    3: "SQLITE_PERM",
    4: "SQLITE_ABORT",
    5: "SQLITE_BUSY",
    6: "SQLITE_LOCKED",
    7: "SQLITE_NOMEM",
    8: "SQLITE_READONLY",
    9: "SQLITE_INTERRUPT",
    10: "SQLITE_IOERR",
    11: "SQLITE_CORRUPT",
    12: "SQLITE_NOTFOUND",
    13: "SQLITE_FULL",
    14: "SQLITE_CANTOPEN",
    15: "SQLITE_PROTOCOL",
    16: "SQLITE_EMPTY",
    17: "SQLITE_SCHEMA",
    18: "SQLITE_TOOBIG",
    19: "SQLITE_CONSTRAINT",
    20: "SQLITE_MISMATCH",
    21: "SQLITE_MISUSE",
    22: "SQLITE_NOLFS",
    23: "SQLITE_AUTH",
    24: "SQLITE_FORMAT",
    25: "SQLITE_RANGE",
    26: "SQLITE_NOTADB",
    27: "SQLITE_NOTICE",
    28: "SQLITE_WARNING",
    100: "SQLITE_ROW",
    101: "SQLITE_DONE",
]

enum ResultCode: CInt, Error, CustomStringConvertible {
    case OK = 0
    case ERROR = 1
    case INTERNAL = 2
    case PERM = 3
    case ABORT = 4
    case BUSY = 5
    case LOCKED = 6
    case NOMEM = 7
    case READONLY = 8
    case INTERRUPT = 9
    case IOERR = 10
    case CORRUPT = 11
    case NOTFOUND = 12
    case FULL = 13
    case CANTOPEN = 14
    case PROTOCOL = 15
    case EMPTY = 16
    case SCHEMA = 17
    case TOOBIG = 18
    case CONSTRAINT = 19
    case MISMATCH = 20
    case MISUSE = 21
    case NOLFS = 22
    case AUTH = 23
    case FORMAT = 24
    case RANGE = 25
    case NOTADB = 26
    case NOTICE = 27
    case WARNING = 28
    case ROW = 100
    case DONE = 101

    public var description: String {
        let message = String(cString: sqlite3_errstr(rawValue))
        let name = ResultCode.nameForCode(rawValue)
        return "\(name) (\(message))"
    }

    /// create a ResultCode from a known-good sqlite error code
    init(_ validCode: CInt) throws {
        let primaryCode = validCode & 0xFF
        guard let resultCode = ResultCode(rawValue: primaryCode) else {
            throw SwiftDBError.unexpected(message: "SQLite returned invalid result code \(validCode)")
        }
        self = resultCode
    }
    
    static func nameForCode(_ code: CInt) -> String {
        return codeNames[code] ?? "UNKNOWN CODE \(code)"
    }
}
