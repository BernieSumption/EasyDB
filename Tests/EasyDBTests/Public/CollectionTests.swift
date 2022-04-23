import XCTest
import EasyDB

class CollectionTests: EasyDBTestCase {

    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
    }

    func testMigrateData() throws {
        db = EasyDB(.memory)
        let v1c = try db.collection(V1.self)
        let record1 = V1(a: 4)
        let record2 = V1(a: 5)
        try v1c.insert([record1, record2])

        let v2c = try db.collection(V2.self)
        let record3 = V2(a: 6, b: "yo")
        try v2c.insert(record3)
        let rows = try v2c.all().fetchMany()
        XCTAssertEqual(rows, [
            V2(id: record1.id, a: 4, b: nil),
            V2(id: record2.id, a: 5, b: nil),
            record3
        ])

        struct V1: Record, Equatable {
            var id = UUID()
            var a: Int

            static let tableName = "x"
        }
        struct V2: Record, Equatable {
            var id = UUID()
            var a: Int
            var b: String?

            static let tableName = "x"
        }
    }

    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)

        // create rows where reading row #2 will cause an error
        try db.execute(#"INSERT INTO Row (id, t) VALUES (1, 'OK'), (2, NULL)"#)

        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.all().fetchMany())

        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        XCTAssertNoThrow(try c.all().fetchOne())

        struct Row: Record, Equatable {
            var id: Int
            var t: String
        }
    }

    let eWithAcuteCombining = "\u{0065}\u{0301}" // "Latin Small Letter E" followed by "Combining Acute Accent"
    let eWithAcute = "\u{00E9}" // "Latin Small Letter E with Acute"

    func testDefaultColumnCollation() throws {
        db = EasyDB(.memory)
        let c = try db.collection(RowWithString.self)
        try c.insert([RowWithString(eWithAcute), RowWithString(eWithAcuteCombining)])

        let all = try c.filter(\.string, equalTo: eWithAcute).fetchMany()
        XCTAssertEqual(all.count, 2)
    }

    func testDefaultCollationOnIndex() throws {
        db = EasyDB(.memory)
        _ = try db.collection(DefaultCollationOnIndex.self)

        let sql = try dbIndices().joined()
        assertString(sql, contains: "`myProp` COLLATE `string`")
    }
    struct DefaultCollationOnIndex: Record, Equatable {
        var id = UUID()
        @Index var myProp: String
    }

    func testColumnCollationOnIndex() throws {
        db = EasyDB(.memory)

        let c = try db.collection(ColumnCollationOnIndex.self)

        try c.insert(ColumnCollationOnIndex(value: "B"))
        try c.insert(ColumnCollationOnIndex(value: "a"))
        try c.insert(ColumnCollationOnIndex(value: "c"))

        // uniqueness-checking on insert should use column collation
        assertErrorMessage(
            try c.insert(ColumnCollationOnIndex(value: "A")),
            contains: "UNIQUE constraint failed: ColumnCollationOnIndex.value")

        // queries should use column collation
        XCTAssertEqual(
            try c.filter(\.value, equalTo: "A").fetchOne()?.value,
            "a")

        // sorting should use column collation
        XCTAssertEqual(
            try c.all().orderBy(\.value).fetchMany().map(\.value),
            ["a", "B", "c"])
    }
    struct ColumnCollationOnIndex: Record, Equatable {
        var id = UUID()
        @CollateCaseInsensitive @Unique var value: String
    }

    func testCollationAnnotation() throws {
        let c = try db.collection(CollationAnnotation.self)
        try c.insert([
            .init(value: "x"),
            .init(value: "me first!"),
            .init(value: "a")
        ])
        XCTAssertEqual(
            try c.all().orderBy(\.value).fetchMany().map(\.value),
            ["me first!", "a", "x"])
    }
    struct CollationAnnotation: Record {
        var id = UUID()
        @CollateCustom @Unique var value: String
    }
}

@propertyWrapper
struct CollateCustom<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public static var propertyConfig: PropertyConfig {
        return .collation(.stringMeFirstAlwaysGoesFirst)
    }
}
