import XCTest
import EasyDB

class DocsTests: EasyDBTestCase {

    func testExecute() throws {
        // docs:start:headline-demo
        // Record types are defined as Codable Swift structs
        let database = Database(.memory)
        struct Book: Codable, Identifiable {
            var id = UUID()
            @Unique var name: String
            var author: String
            var priceCents: Int
        }
        let books = try database.collection(Book.self)
        //  ^^ CREATE TABLE Book (id, name, author, price)
        //     CREATE UNIQUE INDEX `book-unique-id` ON Book (`id`) # ids are automatically unique
        //     CREATE UNIQUE INDEX `book-unique-name` ON Book (`name`)

        try books.insert(Book(name: "Catch-22", author: "Joseph Heller", priceCents: 1050))
        //  ^^ INSERT INTO Book (name, author, price) VALUES (?, ?, ?)

        // fluent type-safe API for querying based on key paths
        let cheapBooks = try books.all()
            .filter(\.priceCents, lessThan: 1000)
            .orderBy(\.author, .descending)
            .fetchMany()
        //  ^^ SELECT * FROM Book WHERE `price` < ? ORDER BY `author` DESC
        // docs:end

        XCTAssertNotNil(cheapBooks)
    }
}
