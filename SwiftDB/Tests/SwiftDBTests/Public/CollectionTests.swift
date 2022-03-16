import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db: Database!
    
    override func setUpWithError() throws {
        db = Database(path: ":memory:", options: .init(logSQL: true))
    }
    
    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
    }
    
    func testInsertAndSelect() throws {
        let c = try db.collection(KitchenSinkEntity.self)
        try c.insert(KitchenSinkEntity.standard)
        let row = try c.all().fetchOne()
        XCTAssertEqual(row, KitchenSinkEntity.standard)
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
        let c = try db.collection(Row.self, [.unique(\.value)])
        try c.insert(Row(value: 5))
        
        assertThrowsConnectionError(
            try c.insert(Row(value: 5)),
            "UNIQUE constraint failed: Row.value")
        
        XCTAssertNoThrow(try c.insert(Row(value: 6)))
    }
    
    func testRegularIndex() throws {
        let c = try db.collection(Row.self, [.index(\.value)])
        try c.insert(Row(value: 5))
        XCTAssertNoThrow(try c.insert(Row(value: 5)))
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
    
    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)
        
        // create rows where reading row #2 will cause an error
        try c.execute(sql: #"INSERT INTO Row (t) VALUES ('OK'), (NULL)"#)
        
        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.all().fetchMany())
        
        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        XCTAssertNoThrow(try c.all().fetchOne())
        
        struct Row: Codable, Equatable {
            let t: String
        }
    }
    
    func testFilterEquals() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, is: 3) },
            [3])
    }
    
    func testFilterEqualsWithJSONValues() throws {
        try testFilter(
            [[1, 2], [2, 2], [3, 1]],
            { try $0.filter(\.value, is: [2, 2]) },
            [[2, 2]])
    }
    
    func testFilterNotEquals() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, isNot: 3) },
            [1, 2, 4, 5])
    }

    func testFilterLessThan() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, lessThan: 3) },
            [1, 2])
    }

    func testFilterLessThanOrEqualTo() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, lessThanOrEqualTo: 3) },
            [1, 2, 3])
    }

    func testFilterGreaterThan() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, greaterThan: 3) },
            [4, 5])
    }

    func testFilterGreaterThanOrEqualTo() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, greaterThanOrEqualTo: 3) },
            [3, 4, 5])
    }

    func testFilterChaining() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, lessThan: 4).filter(\.value, greaterThan: 1) },
            [2, 3])
    }
    
    func testIsNull() throws {
        try testFilter(
            [1, nil, 3, nil, 5],
            { try $0.filter(\.value, isNull: true) },
            [nil, nil])
        
        try testFilter(
            [1, nil, 3, nil, 5],
            { try $0.filter(\.value, is: nil) },
            [nil, nil])
    }

    func testIsNotNull() throws {
        try testFilter(
            [1, nil, 3, nil, 5],
            { try $0.filter(\.value, isNull: false) },
            [1, 3, 5])
        
        try testFilter(
            [1, nil, 3, nil, 5],
            { try $0.filter(\.value, isNot: nil) },
            [1, 3, 5])
    }

    func testLike() throws {
        try testFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { try $0.filter(\.value, like: "foo%") },
            ["foo", "food", "FOO"])
    }

    func testNotLike() throws {
        try testFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { try $0.filter(\.value, notLike: "foo%") },
            ["shizfoo"])
    }

}

extension CollectionTests {
    func assertThrowsConnectionError<T>(_ expression: @autoclosure () throws -> T, _ message: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertEqual((error as! ConnectionError).message, message)
        }
    }
    
    func testFilter<T: Codable & Equatable>(_ data: [T], _ filter: (Collection<RowT<T>>) throws -> QueryBuilder<RowT<T>>, _ expected: [T]) throws {
        try setUpWithError() // delete existing data
        let c = try db.collection(RowT<T>.self)
        try c.insert(data.map(RowT<T>.init))
        XCTAssertEqual(
            try filter(c).fetchMany().map(\.value),
            expected)
    }
    
    struct Row: Codable, Equatable {
        var value: Int
    }
    
    struct RowT<T: Codable & Equatable>: Codable, Equatable {
        var value: T
    }
    
    struct RowWithId: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
    }
}
