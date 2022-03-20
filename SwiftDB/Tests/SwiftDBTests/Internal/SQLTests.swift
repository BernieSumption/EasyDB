import XCTest
@testable import SwiftDB
import SQLite3

class SQLTests: XCTestCase {
    func testNameNormalzation() throws {
        let base = "Abcdé"
        let equal = "aBcdé"
        let notEqual = "AbcdÉ"
        
        // Equal according to SQLite rules
        XCTAssertEqual(sqlite3_stricmp(base, equal), 0)
        XCTAssertEqual(SQL.normalizeName(base), SQL.normalizeName(equal))
        
        // Incorrectly equal with a unicode-aware case-insensitive compare
        XCTAssertEqual(base.caseInsensitiveCompare(notEqual), .orderedSame)
        
        // Not equal according to SQLite rules
        XCTAssertNotEqual(sqlite3_stricmp(base, notEqual), 0)
        XCTAssertNotEqual(SQL.normalizeName(base), SQL.normalizeName(notEqual))
    }
}
