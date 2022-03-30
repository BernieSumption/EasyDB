import XCTest
import SwiftDB

class CollectionTests: SwiftDBTestCase {
    
    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
    }
    
    func testCollectionConfiguration() throws {
        db = Database(path: ":memory:",
                      .collection(Row.self, tableName: "row"),
                      .collection(Row.self, tableName: "row"))
        assertErrorMessage(
            try db.collection(Row.self),
            contains: "Collection Row is configured twice"
        )
    }
    
    func testMigrateData() throws {
        db = Database(path: ":memory:",
                      .collection(V1.self, tableName: "x"),
                      .collection(V2.self, tableName: "x"))
        let v1c = try db.collection(V1.self)
        try v1c.insert(V1(a: 4))
        try v1c.insert(V1(a: 5))
        
        let v2c = try db.collection(V2.self)
        
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
        db = Database(path: ":memory:", .collection(RowWithString.self))
        let c = try db.collection(RowWithString.self)
        try c.insert([RowWithString(eWithAcute), RowWithString(eWithAcuteCombining)])
        
        let all = try c.filter(\.string, equalTo: eWithAcute).fetchMany()
        XCTAssertEqual(all.count, 2)
    }
    
    func testDefaultColumnCollationIndex() throws {
        db = Database(path: ":memory:", .collection(RowWithString.self, .column(\.string, unique: true)))
        let _ = try db.collection(RowWithString.self)
        
        // check that the index has been created with the correct collation
        let sql = try db.execute(String.self, #"SELECT sql FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'RowWithString'"#)
        XCTAssertTrue(sql.contains(#""string" COLLATE "string"#))
    }
    
    func testDefaultCollation() throws {
        db = Database(path: ":memory:",
                      .collection(RowWithString.self,
                                  .column(\.string, collation: .caseInsensitive, unique: true)))
        
        let c = try db.collection(RowWithString.self)
        
        try c.insert(RowWithString("a"))
        try c.insert(RowWithString("B"))
        try c.insert(RowWithString("c"))
        
        assertErrorMessage(
            try c.insert(RowWithString("A")),
            contains: "UNIQUE constraint failed: RowWithString.string")
        
        XCTAssertEqual(
            try c.filter(\.string, equalTo: "A").fetchOne(),
            RowWithString("a"))
        
        
        XCTAssertEqual(
            try c.all().fetchMany().map(\.string),
            ["a", "B", "c"])
    }
    
    func testDefaultCollationX() throws {
        db = Database(path: ":memory:",
                      .collection(RowWithString.self,
                                  .column(\.string, collation: .caseInsensitive, unique: true)))
        
        let c = try db.collection(RowWithString.self)
        
        try c.insert(RowWithString("a"))
        try c.insert(RowWithString("B"))
        try c.insert(RowWithString("c"))
        
        assertErrorMessage(
            try c.insert(RowWithString("A")),
            contains: "UNIQUE constraint failed: RowWithString.string")
        
        XCTAssertEqual(
            try c.filter(\.string, equalTo: "A").fetchOne(),
            RowWithString("a"))
        
        
        XCTAssertEqual(
            try c.all().fetchMany().map(\.string),
            ["a", "B", "c"])
    }
    
}

