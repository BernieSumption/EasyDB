import XCTest

@testable import SwiftDB

class ConnectionTests: XCTestCase {

    func testExample() throws {
        let c = try Connection(path: ":memory:")
        let s = try c.prepare(sql: "SELECT 1 as foo, 'bah' as bar")
        XCTAssertEqual(try s.step(), .row)
        XCTAssertEqual(try s.readDouble(column: "foo"), 1.0)
        XCTAssertEqual(try s.readInt(column: "foo"), 1)
        XCTAssertEqual(try s.readInt64(column: "foo"), 1)
        XCTAssertEqual(try s.readText(column: "bar"), "bah")
        XCTAssertEqual(try s.step(), .done)
        XCTAssertThrowsError(try s.step())
    }

}
