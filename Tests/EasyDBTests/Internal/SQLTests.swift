import XCTest
@testable import EasyDB
import SQLite3

class SQLTests: EasyDBTestCase {
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

    func testInterpolateCollection() throws {
        let c = try db.collection(Row.self)
        let sql: SQLFragment<NoProperties> = "foo \(c) baz"
        XCTAssertEqual(
            try sql.sql(collations: nil, overrideCollation: nil, registerCollation: {_ = $0}),
            "foo `Row` baz")
    }

    func testInterpolateCollation() throws {
        let sql: SQLFragment<NoProperties> = "foo \(Collation.caseInsensitive) baz"
        var registered: Collation?
        XCTAssertEqual(
            try sql.sql(collations: nil, overrideCollation: nil, registerCollation: {registered = $0}),
            "foo `caseInsensitive` baz")
        XCTAssertEqual(registered, Collation.caseInsensitive)
    }
}
