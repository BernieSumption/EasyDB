import XCTest
import SwiftDB

class IndexTests: SwiftDBTestCase {

    func testUniqueIndex() throws {
        db = Database(path: ":memory:", .collection(Row.self, .column(\.value, unique: true)))
        let c = try db.collection(Row.self)
        try c.insert(Row(5))

        assertErrorMessage(
            try c.insert(Row(5)),
            contains: "UNIQUE constraint failed: Row.value")

        XCTAssertNoThrow(try c.insert(Row(6)))
    }

    func testRegularIndex() throws {
        db = Database(path: ":memory:", .collection(Row.self, .column(\.value, .index())))
        let c = try db.collection(Row.self)
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

    func testDisableAutoIndexForIdentifiable() throws {
        db = Database(path: ":memory:")
        let c = try db.collection(DisableAutoIndexForIdentifiable.self)

        let row = DisableAutoIndexForIdentifiable()

        XCTAssertNoThrow(try c.insert([row, row]))

        let indices = try dbIndexSQL()
        XCTAssertEqual(indices, [])
    }

    struct DisableAutoIndexForIdentifiable: Codable, Equatable, Identifiable {
        @NotUnique var id: UUID = UUID()
    }

    func testErrorIfColumnConfiguredTwice() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self,
                                  .column(\.value),
                                  .column(\.value)))
        assertErrorMessage(
            try db.collection(RowT<UUID>.self),
            "Column RowT.value has been configured more than once")
    }

    func testErrorIfIndexSpecifiedTwice() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self,
                                  .column(\.value, .index(unique: true), .index(unique: true))))
        assertErrorMessage(
            try db.collection(RowT<UUID>.self),
            contains: "index RowT-unique-value-string already exists")
    }

    func testNoErrorOnNonDuplicateIndex() throws {
        db = Database(path: ":memory:",
                      .collection(RowT<UUID>.self,
                                  .column(\.value,
                                           .index(unique: true),
                                           .index(unique: false),
                                           .index(unique: true, collation: .caseInsensitive),
                                           .index(unique: false, collation: .caseInsensitive),
                                           .index(unique: true, collation: .localized),
                                           .index(unique: false, collation: .localized))))
        // should not throw
        XCTAssertNoThrow(try db.collection(RowT<UUID>.self))
    }
}
