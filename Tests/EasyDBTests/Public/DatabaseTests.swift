import XCTest
import EasyDB

class DatabaseTests: EasyDBTestCase {

    func testExecute() throws {
        try db.execute("CREATE TABLE foo (a, b)")
        try db.execute("INSERT INTO foo (a, b) VALUES ('a', 'b'), ('c', 'd'), ('e', 'f')")
        let aNotEqualTo = "a"
        let result = try db.execute([[String]].self, "SELECT * FROM foo WHERE a != \(aNotEqualTo)")
        XCTAssertEqual(result, [["c", "d"], ["e", "f"]])
    }
}
