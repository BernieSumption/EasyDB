import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db = Database(path: ":memory:")
    
    func testSimpleCodable() throws {
        let c = try db.collection(Row.self)
        try c.insert(Row(i: 4))
        let row = try c.select().fetchOne()
        XCTAssertEqual(row, Row(i: 4))
        
        struct Row: Codable, Equatable {
            let i: Int
        }
    }
    
    func testComplexCodable() throws {
        let c = try db.collection(KitchenSinkEntity.self)
        try c.insert(KitchenSinkEntity.standard)
        let row = try c.select().fetchOne()
        XCTAssertEqual(row, KitchenSinkEntity.standard)
        
        struct Row: Codable, Equatable {
            let i: Int
        }
    }

}
