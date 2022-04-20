import XCTest
import EasyDB

class DocsTests: XCTestCase {

    var database: EasyDB!
    var collection: Collection<Employee>!

    override func setUpWithError() throws {
        database = EasyDB(.memory)
        collection = try database.collection(Employee.self)
        try? FileManager.default.removeItem(atPath: "my-database.sqlite")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: "my-database.sqlite")
    }

    // docs:start:defining-collections
    struct Employee: Codable, Identifiable {
        var id = UUID()
        var name: String
        var salary: Int
    }
    // docs:end

    func testCreateCollection() throws {
        // docs:start:create-collections
        let database = EasyDB("my-database.sqlite")
        let employees = try database.collection(Employee.self)
        // docs:end

        _ = employees
    }

    func testHeadlineDemo() throws {
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

    func testInsert() throws {
        struct UniqueName: Codable, Identifiable {
            var id = UUID()
            @Unique var name: String
        }
        let collection = try database.collection(UniqueName.self)

        // docs:start:insert-one
        try collection.insert(UniqueName(name: "a"))
        // docs:end

        // docs:start:insert-many
        try collection.insert([
            UniqueName(name: "b"),
            UniqueName(name: "c"),
            UniqueName(name: "d")
        ])
        // docs:end

        // docs:start:insert-many-ignore
        try collection.insert([
            UniqueName(name: "d"),
            UniqueName(name: "e")
        ], onConflict: .ignore)
        // docs:end

        XCTAssertEqual(
            try collection.all().fetchMany().map(\.name),
            ["a", "b", "c", "d", "e"])
    }

    func testQuery() throws {

        // docs:start:query-filter
        _ = try collection
            .filter(\.name, lessThanOrEqualTo: "b")
            .orderBy(\.name)
            .limit(3)
            .fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `name` <= 'b' ORDER BY `name` LIMIT 3
        // docs:end

        // docs:start:query-shared
        let filter = collection
            .filter(\.name, lessThanOrEqualTo: "b")
            .orderBy(\.name)

        let count = try filter.fetchCount()
        log("There are \(count) records in total")

        let first10 = try filter.limit(10).fetchMany()
        log("First 10: \(first10)")
        // docs:end

        // dummy log function, we don't actually want to print anything
        func log(_ value: String) {}
    }

    func testQuerySql() throws {
        // docs:start:filter-sql
        // select records where salary is even, though lord knows why
        // you'd want to do that
        _ = try collection.filter("\(\.salary) % 2 == 0").fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == 0
        // docs:end

        // docs:start:filter-sql-extension-use
        _ = try collection.filter(\.salary, isEven: true).fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == ?
        // docs:end

        // docs:start:orderby-sql
        _ = try collection.all().orderBy("\(\.salary) % 2").fetchMany()
        //  ^^ SELECT * FROM MyRecord ORDER BY `count` % 2 == 0
        // docs:end
    }

    func testSubsetQuery() throws {
        // docs:start:subset-query-single
        let names = try collection.all().fetchMany(\.name)
        //  ^^ SELECT `name` FROM `MyRecord`
        // names is typed [String]
        // docs:end

        // docs:start:subset-query-multiple
        struct NameAndId: Codable {
            var id: UUID
            var name: String
        }
        let namesAndIds = try collection.all().fetchMany(NameAndId.self)
        //  ^^ SELECT `id`, `name` FROM `MyRecord`
        // namesAndIds is typed [NameAndId]
        // docs:end

        _ = names
        _ = namesAndIds
    }

    func testUpdate() throws {
        // docs:start:save
        if var row = try collection.all().fetchOne() {
            row.name = "edited"
            try collection.save(row)
        }
        // docs:end

        // docs:start:update
        try collection.all().update(\.name, "new-name")
        //  ^^ UPDATE `MyRecord` SET `name` = ?
        // docs:end

        // docs:start:update-filter
        try collection
            .filter(\.name, equalTo: "old-name")
            .update(\.name, "new-name")
        //  ^^ UPDATE `MyRecord` SET `name` = ? WHERE `id` = ?
        // docs:end

        // docs:start:update-multiple
        try collection
            .all()
            .updating(\.name, "new-name")
            .updating(\.id, UUID())
            .update()
        //  ^^ UPDATE `MyRecord` SET `name` = ?, `id` = ?
        // docs:end

        // docs:start:update-sql
        try collection
            .all()
            .update("\(\.name) = \(\.name) + 1")
        //  ^^ UPDATE `MyRecord` SET `name` = `name` + 1
        // docs:end

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
            try database.collection(Record.self)
        )
        // docs:end

        assertErrorMessage(
            try database.collection(Record.self),
            contains: "Error thrown from Direction.init(from:)")
        assertErrorMessage(
            try database.collection(Record.self),
            contains: "Cannot initialize Direction from invalid String value 0")
    }

    func testAddSupportForInvalidRecordType() throws {
        struct Record: Codable {
            var direction: Direction
        }
        XCTAssertNoThrow(
            try database.collection(Record.self)
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

// docs:start:filter-sql-extension
extension Filterable {
    func filter<V: Codable>(_ property: KeyPath<Row, V>, isEven: Bool) -> QueryBuilder<Row> {
        return filter("\(property) % 2 == \(isEven ? 0 : 1)")
    }
}
// docs:end
