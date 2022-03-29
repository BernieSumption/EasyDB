import XCTest
import SwiftDB

class IndexTests: SwiftDBTestCase {
    
    func testUniqueIndex() throws {
        db = Database(path: ":memory:", .collection(Row.self, .unique(\.value)))
        let c = try db.collection(Row.self)
        try c.insert(Row(5))
        
        assertErrorMessage(
            try c.insert(Row(5)),
            contains: "UNIQUE constraint failed: Row.value")
        
        XCTAssertNoThrow(try c.insert(Row(6)))
    }
    
    func testRegularIndex() throws {
        db = Database(path: ":memory:", .collection(Row.self, .index(\.value)))
        let c = try db.collection(Row.self)
        try c.insert(Row(5))
        XCTAssertNoThrow(try c.insert(Row(5)))
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
        db = Database(path: ":memory:", .collection(RowWithId.self, disableUniqueId: true))
        let c = try db.collection(RowWithId.self)
        let rowA = RowWithId()
        try c.insert(rowA)
        XCTAssertNoThrow(try c.insert(rowA))
    }
    
    func testIndexWithCollation() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self, .index(\.value, collation: .caseInsensitive)))
        // TODO: remove this when we move to up-front creation
        let _ = try db.collection(RowT<UUID>.self)
        
        let sql = try db.execute([String].self, #"SELECT sql FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'RowT'"#)
        
        XCTAssertEqual(sql.count, 1)
        XCTAssertTrue(sql[0].contains(#""value" COLLATE "caseInsensitive""#))
    }
    
    func testErrorIfIndexSpecifiedTwice() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self,
                                  .index(\.value, collation: .caseInsensitive),
                                  .index(\.value, collation: .caseInsensitive)))
        assertErrorMessage(
            try db.collection(RowT<UUID>.self),
            contains: "index RowT-value-caseInsensitive already exists")
    }
    
    func testNoErrorOnNonDuplicateIndex() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self,
                                  .index(\.value),
                                  .index(\.value, collation: .string),
                                  .index(\.value, collation: .localized),
                                  .index(\.value, unique: true),
                                  .index(\.value, unique: true, collation: .string),
                                  .index(\.value, unique: true, collation: .localized)))
        // should not throw
        XCTAssertNoThrow(try db.collection(RowT<UUID>.self))
    }
}


