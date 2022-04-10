import XCTest
import SwiftDB

class CollectionTests: SwiftDBTestCase {

    func testCollectionCaching() {
        XCTAssertTrue(try db.collection(Row.self) === db.collection(Row.self))
    }

    func testCollectionConfiguration() throws {
        db = Database(path: ":memory:",
                      .collection(Row.self, tableName: "row"),
                      .collection(Row.self, tableName: "row"))
        assertErrorMessage(
            try db.collection(Row.self),
            contains: "Collection Row is configured twice"
        )
    }

    func testMigrateData() throws {
        db = Database(path: ":memory:",
                      .collection(V1.self, tableName: "x"),
                      .collection(V2.self, tableName: "x"))
        let v1c = try db.collection(V1.self)
        try v1c.insert(V1(a: 4))
        try v1c.insert(V1(a: 5))

        let v2c = try db.collection(V2.self)

        try v2c.insert(V2(a: 6, b: "yo"))
        let rows = try v2c.all().fetchMany()
        XCTAssertEqual(rows, [V2(a: 4, b: nil), V2(a: 5, b: nil), V2(a: 6, b: "yo")])

        struct V1: Codable, Equatable, CustomTableName {
            var a: Int

            static let tableName = "x"
        }
        struct V2: Codable, Equatable, CustomTableName {
            var a: Int
            var b: String?

            static let tableName = "x"
        }
    }

    func testFetchOneReadsSingleRow() throws {
        let c = try db.collection(Row.self)

        // create rows where reading row #2 will cause an error
        try db.execute(#"INSERT INTO Row (t) VALUES ('OK'), (NULL)"#)

        // check that reading all rows does indeed cause an error
        XCTAssertThrowsError(try c.all().fetchMany())

        // this should not throw an error if we're lazily fetching rows and
        // never try to decode row 2
        XCTAssertNoThrow(try c.all().fetchOne())

        struct Row: Codable, Equatable {
            let t: String
        }
    }

    let eWithAcuteCombining = "\u{0065}\u{0301}" // "Latin Small Letter E" followed by "Combining Acute Accent"
    let eWithAcute = "\u{00E9}" // "Latin Small Letter E with Acute"

    func testDefaultColumnCollation() throws {
        db = Database(path: ":memory:", .collection(RowWithString.self))
        let c = try db.collection(RowWithString.self)
        try c.insert([RowWithString(eWithAcute), RowWithString(eWithAcuteCombining)])

        let all = try c.filter(\.string, equalTo: eWithAcute).fetchMany()
        XCTAssertEqual(all.count, 2)
    }

    func testDefaultCollationOnIndex() throws {
        db = Database(path: ":memory:", .collection(DefaultCollationOnIndex.self))
        _ = try db.collection(DefaultCollationOnIndex.self)

        let sql = try dbIndexSQL().first ?? ""
        XCTAssertTrue(sql.contains("`myProp` COLLATE `string`"))
    }
    struct DefaultCollationOnIndex: Codable, Equatable {
        @Index var myProp: String
    }

    func testColumnCollationOnIndex() throws {
        db = Database(path: ":memory:")

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

    struct ColumnCollationOnIndex: Codable, Equatable {
        @CollateCaseInsensitive @Unique var value: String
    }

}
