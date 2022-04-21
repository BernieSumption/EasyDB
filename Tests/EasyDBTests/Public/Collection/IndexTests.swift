import XCTest
import EasyDB

class IndexTests: EasyDBTestCase {

    func testUniqueIndex() throws {
        db = EasyDB(.memory)
        let c = try db.collection(Row.self)
        try c.insert(Row(value: 5))

        assertErrorMessage(
            try c.insert(Row(value: 5)),
            contains: "UNIQUE constraint failed: Row.value")

        XCTAssertNoThrow(try c.insert(Row(value: 6)))

        struct Row: Codable, Equatable {
            @Unique var value: Int
        }
    }

    func testRegularIndex() throws {
        db = EasyDB(.memory)
        let c = try db.collection(Row.self)
        try c.insert(Row(value: 5))
        XCTAssertNoThrow(try c.insert(Row(value: 5)))

        let sql = try dbIndexSQL().first ?? ""
        XCTAssertTrue(sql.contains("CREATE INDEX `Row-value-string`"))

        struct Row: Codable, Equatable {
            @Index var value: Int
        }
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

    func testAutoIndexForIdentifiableWithCodingKeys() throws {
        let c = try db.collection(RowWithIdUsingCodingKeys.self)
        let rowA = RowWithIdUsingCodingKeys()
        let rowB = RowWithIdUsingCodingKeys()
        try c.insert(rowA)

        assertErrorMessage(
            try c.insert(rowA),
            contains: "UNIQUE constraint failed: RowWithIdUsingCodingKeys.altIdField")

        XCTAssertNoThrow(try c.insert(rowB))
    }

    struct RowWithIdUsingCodingKeys: Codable, Equatable, Identifiable {
        let id: UUID

        init(_ id: UUID = UUID()) {
            self.id = id
        }

        enum CodingKeys: String, CodingKey {
            case id = "altIdField"
        }
    }

    func testRegularIndexForIdentifiableIsUnique() throws {
        db = EasyDB(.memory)
        let c = try db.collection(RegularIndexForIdentifiableIsUnique.self)

        let row = RegularIndexForIdentifiableIsUnique()

        try c.insert(row)

        assertErrorMessage(
            try c.insert(row),
            contains: "UNIQUE constraint failed: RegularIndexForIdentifiableIsUnique.id")

        let indices = try dbIndexSQL()
        XCTAssertEqual(indices.count, 1)
    }

    struct RegularIndexForIdentifiableIsUnique: Codable, Equatable, Identifiable {
        @Index var id: UUID = UUID()
    }
}
