import XCTest

@testable import SwiftDB

class ConnectionTests: XCTestCase {

    func testRead() throws {
        let c = try Connection(path: ":memory:")
        let s = try c.prepare(sql: "SELECT 1 as foo, 'bah' as bar, NULL as nil")
        XCTAssertEqual(try s.step(), .row)

        XCTAssertEqual(try s.readDouble(column: "foo"), 1.0)
        XCTAssertEqual(try s.readInt(column: "foo"), 1)
        XCTAssertEqual(try s.readText(column: "bar"), "bah")

        XCTAssertEqual(try s.readNull(column: "foo"), false)
        XCTAssertEqual(try s.readNull(column: "bar"), false)
        XCTAssertEqual(try s.readNull(column: "nil"), true)
        XCTAssertEqual(try s.readDouble(column: "nil"), 0)
        XCTAssertEqual(try s.readInt(column: "nil"), 0)
        XCTAssertEqual(try s.readText(column: "nil"), "")

        XCTAssertEqual(try s.step(), .done)
        XCTAssertThrowsError(try s.step())

        try s.reset()
        XCTAssertEqual(try s.step(), .row)
        XCTAssertEqual(try s.readDouble(column: "foo"), 1.0)
    }

    func testWrite() throws {
        let c = try Connection(path: ":memory:")
        let create = try c.prepare(sql: "CREATE TABLE tmp (a)")
        XCTAssertEqual(try create.step(), .done)

        let insertStmt = try c.prepare(sql: "INSERT INTO tmp VALUES (?)")
        let selectStmt = try c.prepare(sql: "SELECT a FROM tmp ORDER BY rowid DESC LIMIT 1")

        func insert(_ parameter: DatabaseValue) throws {
            try insertStmt.reset()
            try insertStmt.bind([parameter])
            XCTAssertEqual(try insertStmt.step(), .done)
            try selectStmt.reset()
            XCTAssertEqual(try selectStmt.step(), .row)
        }

        try insert(.int(100))
        XCTAssertEqual(try selectStmt.readInt(column: "a"), 100)

        try insert(.double(123.45))
        XCTAssertEqual(try selectStmt.readDouble(column: "a"), 123.45)

        try insert(.text("Unicode 统一码 😘"))
        XCTAssertEqual(try selectStmt.readText(column: "a"), "Unicode 统一码 😘")

        try insert(.text("foo"))
        XCTAssertEqual(try selectStmt.readText(column: "a"), "foo")

        try insert(.text(""))
        XCTAssertEqual(try selectStmt.readText(column: "a"), "")

        let someData = Data([1, 3, 0, 255, 200, 180, 21, 0, 7])
        try insert(.blob(someData))
        XCTAssertEqual(try selectStmt.readBlob(column: "a"), someData)

        try insert(.null)
        XCTAssertEqual(try selectStmt.readNull(column: "a"), true)
    }
}
