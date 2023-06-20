import XCTest

@testable import EasyDB

class ConnectionTests: EasyDBTestCase {

    func testRead() throws {
        let c = try getConnection()
        let s = try c.prepare(sql: """
            SELECT
                1 as int,
                1.5 as double,
                'X' as text,
                x'1234' as blob,
                NULL as nil
        """)
        XCTAssertEqual(try s.step(), .row)

        XCTAssertEqual(try s.read(column: "int"), .int(1))
        XCTAssertEqual(try s.read(column: "double"), .double(1.5))
        XCTAssertEqual(try s.read(column: "text"), .text("X"))
        XCTAssertEqual(try s.read(column: "blob"), .blob(Data([0x12, 0x34])))
        XCTAssertEqual(try s.read(column: "nil"), .null)

        s.reset()
        XCTAssertEqual(try s.step(), .row)
        XCTAssertEqual(try s.read(column: "int"), .int(1))
    }

    func testWrite() throws {
        let c = try getConnection()
        let create = try c.prepare(sql: "CREATE TABLE tmp (a)")
        XCTAssertEqual(try create.step(), .done)

        let insertStmt = try c.prepare(sql: "INSERT INTO tmp VALUES (?)")
        let selectStmt = try c.prepare(sql: "SELECT a FROM tmp ORDER BY rowid DESC LIMIT 1")

        func test(_ parameter: DatabaseValue) throws {
            insertStmt.reset()
            try insertStmt.bind([parameter])
            XCTAssertEqual(try insertStmt.step(), .done)
            selectStmt.reset()
            XCTAssertEqual(try selectStmt.step(), .row)
            XCTAssertEqual(try selectStmt.read(column: "a"), parameter)
        }

        try test(.int(100))
        try test(.double(123.45))
        try test(.text("Unicode 统一码 😘"))
        try test(.text("foo"))
        try test(.text(""))
        try test(.blob(Data([1, 3, 0, 255, 200, 180, 21, 0, 7])))
        try test(.blob(Data()))
        try test(.null)
    }
}
