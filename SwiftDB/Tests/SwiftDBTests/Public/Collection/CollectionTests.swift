import XCTest
import SwiftDB

class CollectionTests: SwiftDBTestCase {
    
    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
    }
    
    func testCollectionConfiguration() throws {
        db = Database(path: ":memory:",
                      .collection(Row.self, tableName: "row"),
                      .collection(V2.self, tableName: "x"))
        
    }
    
    func testMigrateData() throws {
        db = Database(path: ":memory:",
                      .collection(V1.self, tableName: "x"),
                      .collection(V2.self, tableName: "x"))
        let v1c = try db.collection(V1.self, [.tableName("x")])
        try v1c.insert(V1(a: 4))
        try v1c.insert(V1(a: 5))
        
        let v2c = try db.collection(V2.self, [.tableName("x")])
        
        try v2c.insert(V2(a: 6, b: "yo"))
        let rows = try v2c.all().fetchMany()
        XCTAssertEqual(rows, [V2(a: 4, b: nil), V2(a: 5, b: nil), V2(a: 6, b: "yo")])
        
        struct V1: Codable, Equatable {
            var a: Int
        }
        struct V2: Codable, Equatable {
            var a: Int
            var b: String?
        }
    }
    
    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)
        
        // create rows where reading row #2 will cause an error
        try db.execute(#"INSERT INTO Row (t) VALUES ('OK'), (NULL)"#)
        
        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.all().fetchMany())
        
        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        XCTAssertNoThrow(try c.all().fetchOne())
        
        struct Row: Codable, Equatable {
            let t: String
        }
    }
    
    let eWithAcuteCombining = "\u{0065}\u{0301}" // "Latin Small Letter E" followed by "Combining Acute Accent"
    let eWithAcute = "\u{00E9}" // "Latin Small Letter E with Acute"
    
    func testDefaultColumnCollation() throws {
        let c = try db.collection(RowT<String>.self, [.tableName("t")])
        try c.insert([RowT(eWithAcute), RowT(eWithAcuteCombining)])
        
        let sql = try db.execute(String.self, #"SELECT sql FROM sqlite_schema WHERE type = 'table' AND tbl_name = 't'"#)
        XCTAssertTrue(sql.contains(#""value" COLLATE "string"#))
        
        let count = try db.execute(Int.self, "SELECT COUNT(*) FROM t WHERE value = \(eWithAcute)")
        XCTAssertEqual(count, 2)
    }
    
}

