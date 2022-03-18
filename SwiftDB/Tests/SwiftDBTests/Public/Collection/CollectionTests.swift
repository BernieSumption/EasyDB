import XCTest
import SwiftDB

class CollectionTests: SwiftDBTestCase {
    
    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(RowWithValue.self) === db.collection(RowWithValue.self))
    }
    
    func testMigrateData() throws {
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
    
    func testUniqueIndex() throws {
        let c = try db.collection(RowWithValue.self, [.unique(\.value)])
        try c.insert(RowWithValue(5))
        
        assertThrowsConnectionError(
            try c.insert(RowWithValue(5)),
            "UNIQUE constraint failed: RowWithValue.value")
        
        XCTAssertNoThrow(try c.insert(RowWithValue(6)))
    }
    
    func testRegularIndex() throws {
        let c = try db.collection(RowWithValue.self, [.index(\.value)])
        try c.insert(RowWithValue(5))
        XCTAssertNoThrow(try c.insert(RowWithValue(5)))
    }
    
    func testAutoIndexForIdentifiable() throws {
        let c = try db.collection(RowWithId.self)
        let rowA = RowWithId()
        let rowB = RowWithId()
        try c.insert(rowA)
        
        assertThrowsConnectionError(
            try c.insert(rowA),
            "UNIQUE constraint failed: RowWithId.id")
        
        XCTAssertNoThrow(try c.insert(rowB))
    }
    
    func testNoUniqueId() throws {
        let c = try db.collection(RowWithId.self, [.noUniqueId])
        let rowA = RowWithId()
        try c.insert(rowA)
        XCTAssertNoThrow(try c.insert(rowA))
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
    
}

