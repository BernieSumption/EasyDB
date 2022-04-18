import XCTest
import EasyDB

class DocsTests: EasyDBTestCase {

    func testHeadlineDemo() throws {
        try? FileManager.default.removeItem(atPath: "my-database.sqlite")
        defer { try? FileManager.default.removeItem(atPath: "my-database.sqlite") }
        // docs:start:headline-demo
        // Record types are defined as Codable structs
        struct Book: Codable, Identifiable {
            var id = UUID()
            @Unique var name: String
            var author: String
            var priceCents: Int
        }
        let database = EasyDB("my-database.sqlite")
        let books = try database.collection(Book.self)
        //  ^^ CREATE TABLE Book (id, name, author, price)
        //     CREATE UNIQUE INDEX `book-unique-id` ON Book (`id`) # ids are automatically unique
        //     CREATE UNIQUE INDEX `book-unique-name` ON Book (`name`)

        try books.insert(Book(name: "Catch-22", author: "Joseph Heller", priceCents: 1050))
        //  ^^ INSERT INTO Book (id, name, author, priceCents) VALUES (?, ?, ?, ?)

        // fluent type-safe API for querying based on key paths
        let cheapBooks = try books.all()
            .filter(\.priceCents, lessThan: 1000)
            .orderBy(\.author, .descending)
            .fetchMany()
        //  ^^ SELECT * FROM Book WHERE `priceCents` < ? ORDER BY `author` DESC
        // docs:end

        XCTAssertNotNil(cheapBooks)
    }

    func testDefiningCollections() throws {
        // docs:start:defining-collections
        struct MyRecord: Codable, Identifiable {
            var id = UUID()
            var name: String
        }
        // docs:end

        _ = try db.collection(MyRecord.self)
    }

    func testInvalidRecordType() throws {
        // docs:start:invalid-record-type
        struct Record: Codable {
            var direction: Direction
        }
        // "0" is not a valid value for this enum
        enum Direction: String, Codable {
            case up, down, left, right
        }
        XCTAssertThrowsError(
            // message: Error thrown from Direction.init(from:) ... Cannot initialize
            //          Direction from invalid String value 0
            try db.collection(Record.self)
        )
        // docs:end
        assertErrorMessage(
            try db.collection(Record.self),
            contains: "Error thrown from Direction.init(from:)")
        assertErrorMessage(
            try db.collection(Record.self),
            contains: "Cannot initialize Direction from invalid String value 0")
    }

    func testAddSupportForInvalidRecordType() throws {
        struct Record: Codable {
            var direction: Direction
        }
        XCTAssertNoThrow(
            try db.collection(Record.self)
        )
    }
}

enum Direction: Codable {
    case up, down, left, right
}
// docs:start:fix-invalid-record-type
extension Direction: SampleValueSource {
    // return a `SampleValues` containing any two different instances
    static let sampleValues = SampleValues(Direction.up, Direction.down)
}
// docs:end
