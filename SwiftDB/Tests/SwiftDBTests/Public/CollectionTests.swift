import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db: Database!
    
    override func setUpWithError() throws {
        db = Database(path: ":memory:", options: .init(logSQL: true))
    }
    
    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
        
        struct Row: Codable, Equatable {
            let i: Int
        }
    }
    
    func testInsertAndSelect() throws {
        let c = try db.collection(KitchenSinkEntity.self)
        try c.insert(KitchenSinkEntity.standard)
        let row = try c.select().fetchOne()
        XCTAssertEqual(row, KitchenSinkEntity.standard)
    }
    
    func testMigrateData() throws {
        let v1c = try db.collection(V1.self, [.tableName("x")])
        try v1c.insert(V1(a: 4))
        try v1c.insert(V1(a: 5))
        
        let v2c = try db.collection(V2.self, [.tableName("x")])
        
        try v2c.insert(V2(a: 6, b: "yo"))
        let rows = try v2c.select().fetchMany()
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
        let c = try db.collection(Row.self, [.unique(\.unique), .index(\.regular)])
        try c.insert(Row(unique: 4, regular: 5))
        
        XCTAssertNoThrow(try c.insert(Row(unique: 1, regular: 5)))
        
        assertThrowsConnectionError(
            try c.insert(Row(unique: 4, regular: 8)),
            "UNIQUE constraint failed: Row.unique")
        
        struct Row: Codable, Equatable {
            let unique: Int
            let regular: Int
        }
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
    
    func testNoUniqueIdForIdentifiable() throws {
        let c = try db.collection(RowWithId.self, [.noUniqueId])
        let rowA = RowWithId()
        try c.insert(rowA)
        XCTAssertNoThrow(try c.insert(rowA))
    }
    
    struct RowWithId: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
    }
    
    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)
        
        // create rows where reading row #2 will cause an error
        try c.execute(sql: #"INSERT INTO Row (t) VALUES ('OK'), (NULL)"#)
        
        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.select().fetchMany())
        
        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        XCTAssertNoThrow(try c.select().fetchOne())
        
        struct Row: Codable, Equatable {
            let t: String
        }
    }

}

extension CollectionTests {
    func assertThrowsConnectionError<T>(_ expression: @autoclosure () throws -> T, _ message: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertEqual((error as! ConnectionError).message, message)
        }
    }
}
