import XCTest
import SwiftDB

class IndexTests: SwiftDBTestCase {
    
    func testUniqueIndex() throws {
        db = Database(path: ":memory:", options: [.logSQL(true)])
        let c = try db.collection(Row.self, [.unique(\.value)])
        try c.insert(Row(5))
        
        assertErrorMessage(
            try c.insert(Row(5)),
            contains: "UNIQUE constraint failed: Row.value")
        
        XCTAssertNoThrow(try c.insert(Row(6)))
    }
    
    func testRegularIndex() throws {
        let c = try db.collection(Row.self, [.index(\.value)])
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
        let c = try db.collection(RowWithId.self, [.noUniqueId])
        let rowA = RowWithId()
        try c.insert(rowA)
        XCTAssertNoThrow(try c.insert(rowA))
    }
    
    func testIndexWithCollation() throws {
        let _ = try db.collection(RowT<UUID>.self, [
            .index(\.value, collation: .caseInsensitive),
            .tableName("t")
        ])
        
        let sql = try db.execute([String].self, #"SELECT sql FROM sqlite_schema WHERE type = 'index' AND tbl_name = 't'"#)
        
        XCTAssertEqual(sql.count, 1)
        XCTAssertTrue(sql[0].contains(#""value" COLLATE "caseInsensitive""#))
    }
    
    func testErrorIfIndexSpecifiedTwice() throws {
        assertErrorMessage(
            try db.collection(RowT<UUID>.self, [
                .index(\.value, collation: .caseInsensitive),
                .index(\.value, collation: .caseInsensitive),
                .tableName("t")
            ]),
            contains: "index t-value-caseInsensitive already exists")
    }
    
    func testNoErrorOnNonDuplicateIndex() throws {
        // should not throw
        XCTAssertNoThrow(
            try db.collection(RowT<UUID>.self, [
                .index(\.value),
                .index(\.value, collation: .string),
                .index(\.value, collation: .localized),
                .index(\.value, unique: true),
                .index(\.value, unique: true, collation: .string),
                .index(\.value, unique: true, collation: .localized),
                .tableName("t")
            ]))
    }
}


