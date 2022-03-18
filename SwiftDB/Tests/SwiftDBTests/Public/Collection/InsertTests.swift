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
    
// TODO: restore this test when we implement transactions
//    func testBulkInsertUsesTransaction() throws {
//        let c = try db.collection(RowWithId.self)
//        var rows = [RowWithId(), RowWithId()]
//        rows.append(rows[0])
//        assertThrowsConnectionError(try c.insert(rows), contains: "UNIQUE constraint failed")
//        XCTAssertEqual(try c.all().fetchMany(), [])
//    }
}

