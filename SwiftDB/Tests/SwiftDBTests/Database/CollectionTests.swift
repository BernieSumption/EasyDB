import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db = Database(path: ":memory:", options: .init(logSQL: true))
    
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
        let c = try db.collection(Row.self, [.unique(\.foo)])
        try c.insert(Row(foo: 4))
        
        XCTAssertThrowsError(try c.insert(Row(foo: 4))) { error in
            XCTAssertEqual(
                (error as? ConnectionError)?.message,
                "UNIQUE constraint failed: Row.foo"
            )
        }
        
        struct Row: Codable, Equatable {
            let foo: Int
        }
    }
    
    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)
        
        // create rows where reading row #2 will cause an error
        try c.execute(sql: #"INSERT INTO Row (t) VALUES ('OK'), ('error row 2 blocked')"#)
        
        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.select().fetchMany()) { error in
            XCTAssertEqual("\(error)", "error row 2 blocked")
        }
        
        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        let _ = try c.select().fetchOne()
        
        struct Row: Codable, Equatable {
            let t: Throw
        }
    }

}

/// A decodable type that serialises to a single string and throws an error during decoding if the string starts with `"error"`
struct Throw: Codable, Equatable {
    let value: String
    
    init(_ value: String) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
        print(value)
        if value.starts(with: "error") {
            throw Invalid(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    struct Invalid: Swift.Error, CustomDebugStringConvertible {
        let message: String
        
        init(_ message: String) {
            self.message = message
        }
        
        var debugDescription: String { message }
    }
}
