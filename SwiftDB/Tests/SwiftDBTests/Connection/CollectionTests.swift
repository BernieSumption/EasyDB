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
    }
    
    func testMigrateData() throws {
        let c = try db.collection(V1.self, .init(tableName: "x"))
        try c.insert(V1(a: 4))
        try c.insert(V1(a: 5))
        
        let c2 = try db.collection(V2.self, .init(tableName: "x"))
        let rows = try c2.select().fetchMany()
        XCTAssertEqual(rows, [V2(a: 4, b: nil), V2(a: 5, b: nil)])
    }
    
    struct V1: Codable, Equatable {
        var a: Int
    }
    struct V2: Codable, Equatable {
        var a: Int
        var b: String?
    }

}
