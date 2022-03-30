import XCTest
import SwiftDB

class InsertTests: SwiftDBTestCase {
    
    func testInsert() throws {
        let c = try db.collection(KitchenSinkEntity.self)
        try c.insert(KitchenSinkEntity.standard)
        let row = try c.all().fetchOne()
        XCTAssertEqual(row, KitchenSinkEntity.standard)
    }
    
    func testBulkInsert() throws {
        let c = try db.collection(RowWithId.self)
        let rows = [RowWithId(), RowWithId()]
        try c.insert(rows)
        XCTAssertEqual(try c.all().fetchMany(), rows)
    }
    
    func testBulkInsertUsesTransaction() throws {
        let c = try db.collection(RowWithId.self)
        let a = RowWithId()
        let b = RowWithId()
        // should fail to insert the second `a`, so roll back and leave an empty collection
        assertErrorMessage(try c.insert([a, b, a]), contains: "UNIQUE constraint failed")
        XCTAssertEqual(try c.all().fetchMany(), [])
    }
}

