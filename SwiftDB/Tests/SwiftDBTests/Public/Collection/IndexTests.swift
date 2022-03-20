import XCTest
import SwiftDB

class IndexTests: SwiftDBTestCase {
    
    func testUniqueIndex() throws {
        db = Database(path: ":memory:", options: [.logSQL(true)])
        let c = try db.collection(RowWithValue<Int>.self, [.unique(\.value)])
        try c.insert(RowWithValue(5))
        
        assertErrorMessage(
            try c.insert(RowWithValue(5)),
            contains: "UNIQUE constraint failed: RowWithValue<Int>.value")
        
        XCTAssertNoThrow(try c.insert(RowWithValue(6)))
    }
    
    func testRegularIndex() throws {
        let c = try db.collection(RowWithValue<Int>.self, [.index(\.value)])
        try c.insert(RowWithValue(5))
        XCTAssertNoThrow(try c.insert(RowWithValue(5)))
    }
    
    func testAutoIndexForIdentifiable() throws {
        let c = try db.collection(RowWithId.self)
        let rowA = RowWithId()
        let rowB = RowWithId()
        try c.insert(rowA)
        
        assertErrorMessage(
            try c.insert(rowA),
            contains: "UNIQUE constraint failed: RowWithId.id")
        
        XCTAssertNoThrow(try c.insert(rowB))
    }
    
    func testNoUniqueId() throws {
        let c = try db.collection(RowWithId.self, [.noUniqueId])
        let rowA = RowWithId()
        try c.insert(rowA)
        XCTAssertNoThrow(try c.insert(rowA))
    }
    
    func testIndexWithCollation() throws {
        let _ = try db.collection(RowWithValue<UUID>.self, [
            .index(\.value, name: "testIndex", collation: .caseInsensitiveCompare),
            .tableName("t")
        ])
        
        let sql = try db.execute(String.self, #"SELECT sql FROM sqlite_schema WHERE type = 'index' AND name = 'testIndex'"#)
        
        XCTAssertEqual(sql, #"CREATE INDEX "testIndex" ON "t" ( "value" COLLATE "caseInsensitiveCompare" )"#)
    }
}


