import XCTest
import EasyDB

// swiftlint:disable file_length

class DocsTests: EasyDBTestCase {

    var database: EasyDB!
    var employees: Collection<Employee>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = db!
        employees = try database.collection(Employee.self)
        try? FileManager.default.removeItem(atPath: "my-database.sqlite")
    }

    override func tearDownWithError() throws {
        database = nil
        employees = nil
        try? FileManager.default.removeItem(atPath: "my-database.sqlite")
        try super.tearDownWithError()
    }

    // docs:start:defining-collections
    struct Employee: Record {
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
        struct Book: Record {
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

    func testSave() throws {
        // docs:start:save-one
        try employees.save(Employee(name: "Peter Gibbons", salary: 40250))
        // docs:end

        // docs:start:save-many
        try employees.save([
            Employee(name: "Samir Nagheenanajar", salary: 40_250),
            Employee(name: "Michael Bolton", salary: 40_250),
            Employee(name: "Bill Lumbergh", salary: 110_000)
        ])
        // docs:end

        // docs:start:fetch-edit-save
        // load a random Employee
        if var row = try employees.all().orderBy("random()").fetchOne() {
            // reverse the words their name
            row.name = row.name.split(separator: " ").reversed().joined(separator: " ")
            // save the record
            try employees.save(row)
        }
        // docs:end
    }

    func testQuery() throws {

        // docs:start:query-filter
        _ = try employees
            .filter(\.name, lessThanOrEqualTo: "b")
            .orderBy(\.name)
            .limit(3)
            .fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `name` <= 'b' ORDER BY `name` LIMIT 3
        // docs:end

        // docs:start:query-shared
        let filter = employees
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
        _ = try employees.filter("\(\.salary) % 2 == 0").fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == 0
        // docs:end

        // docs:start:filter-sql-extension-use
        _ = try employees.filter(\.salary, isEven: true).fetchMany()
        //  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == ?
        // docs:end

        // docs:start:orderby-sql
        _ = try employees.all().orderBy("\(\.salary) % 2").fetchMany()
        //  ^^ SELECT * FROM MyRecord ORDER BY `count` % 2 == 0
        // docs:end
    }

    func testSubsetQuery() throws {
        // docs:start:subset-query-single
        let names = try employees.all().fetchMany(\.name)
        //  ^^ SELECT `name` FROM `MyRecord`
        // names is typed [String]
        // docs:end

        // docs:start:subset-query-multiple
        struct NameAndId: Codable {
            var id: UUID
            var name: String
        }
        let namesAndIds = try employees.all().fetchMany(NameAndId.self)
        //  ^^ SELECT `id`, `name` FROM `MyRecord`
        // namesAndIds is typed [NameAndId]
        // docs:end

        _ = names
        _ = namesAndIds
    }

    func testUpdate() throws {

        // docs:start:update
        try employees.all().update(\.name, "new-name")
        //  ^^ UPDATE `MyRecord` SET `name` = ?
        // docs:end

        // docs:start:update-filter
        try employees
            .filter(\.name, equalTo: "old-name")
            .update(\.name, "new-name")
        //  ^^ UPDATE `MyRecord` SET `name` = ? WHERE `id` = ?
        // docs:end

        // docs:start:update-multiple
        try employees
            .all()
            .updating(\.name, "new-name")
            .updating(\.id, UUID())
            .update()
        //  ^^ UPDATE `MyRecord` SET `name` = ?, `id` = ?
        // docs:end

        // docs:start:update-sql
        try employees
            .all()
            .update("\(\.name) = \(\.name) + 1")
        //  ^^ UPDATE `MyRecord` SET `name` = `name` + 1
        // docs:end

    }

    func testDelete() throws {
        let thatDudeWeGonnaFire = UUID()

        // docs:start:deleting
        try employees
            .filter(id: thatDudeWeGonnaFire)
            .delete()
        // docs:end
    }

    func testTransactions() throws {
        struct CountAndTotal: Equatable {
            internal init(_ count: Int, _ total: Int) {
                self.count = count
                self.total = total
            }

            var count: Int
            var total: Int
        }

        try employees.insert(Employee(name: "Bernie", salary: 5))

        // docs:start:transaction-bad
        let count = try employees.all().fetchCount()
        // another task could modify the database here, leading to inconsistency
        let total = try database.execute(Int.self, "SELECT SUM(salary) FROM Employee")
        // docs:end

        // docs:start:transaction-good
        let countAndTotal = try database.read {
            let count = try employees.all().fetchCount()
            let total = try database.execute(Int.self, "SELECT SUM(salary) FROM Employee")
            return CountAndTotal(count, total)
        }
        // docs:end

        XCTAssertEqual(count, 1)
        XCTAssertEqual(total, 5)
        XCTAssertEqual(countAndTotal, CountAndTotal(1, 5))
    }

    func testIndices() throws {
        // docs:start:indices
        struct Book: Record {
            var id = UUID() // automatically unique
            @Unique var title: String
            @Index var author: String
            var price: Int
        }
        // docs:end

        // docs:start:indices-custom
        let books = try database.collection(Book.self)
        try database.execute("""
            CREATE INDEX IF NOT EXISTS `book-title-author`
            ON \(books) (`title`, `author`)
        """)
        // docs:end

        // docs:start:indices-custom-migrate
        try database.execute("""
            DROP INDEX IF EXISTS `book-title-author`
        """)
        try database.execute("""
            CREATE INDEX IF NOT EXISTS `book-title-asc-author-desc`
            ON \(books) (`title` ASC, `author` DESC)
        """)
        // docs:end
    }

    func testCollations() throws {
        // docs:start:collation-annotation
        struct Book: Record {
            var id = UUID()
            var author: String
            @CollateCaseInsensitive var name: String
        }

        let books = try database.collection(Book.self)
        try books.insert(Book(author: "Joseph Heller", name: "Catch 22"))
        let count = try books.filter(\.name, equalTo: "CATCH 22").fetchCount()
        XCTAssertEqual(count, 1)
        // docs:end

        // docs:start:collation-annotation-override
        let result = try books
            .filter(\.author, equalTo: "unknown", collation: .caseInsensitive)
            .orderBy(\.name, collation: .binary)
            .fetchMany()
        // docs:end

        _ = result
    }

    func testExecuteSQL() throws {
        // docs:start:execute-sql
        let randomNumber = try database.execute(Int.self, "SELECT random()")

        // or for statements that do not return a value
        try database.execute("PRAGMA case_sensitive_like = true")
        // docs:end
        _ = randomNumber

        // docs:start:execute-sql-interpolation-key-path
        try employees.filter("LENGTH(\(\.name)) < 5").delete()
        //  ^^ DELETE FROM Employees where LENGTH(`name`) < 5
        //     # fire all employees with short names
        // docs:end

        // docs:start:execute-sql-interpolation-string
        let bobbyTables = "Robert'); DROP TABLE Employees;--"
        try database.execute("DELETE from Employee WHERE `name` = \(bobbyTables)")
        //  ^^ DELETE FROM Employees where `name` = ?
        //     # "Robert'); DROP TABLE Employees;--" bound to parameter 1
        //     # Fire Bobby. Nice try Bobby.
        // docs:end

        let lessThan = randomNumber < 10
        // docs:start:execute-sql-interpolation-literal
        let operation = lessThan ? "<" : ">"
        try employees.filter("salary \(literal: operation) 50000").delete()
        //  ^^ DELETE FROM Employees where salary < 50000
        // docs:end

        // docs:start:execute-sql-interpolation-collection
        let employees = try database.collection(Employee.self)
        try database.execute("DROP TABLE \(employees)")
        //  ^^ DROP TABLE `Employees`
        // docs:end

        // docs:start:execute-sql-interpolation-collation
        try database.execute("CREATE TABLE Tmp (col STRING COLLATE \(.caseInsensitive))")
        //  ^^ CREATE TABLE Tmp (col STRING COLLATE `caseInsensitive`)
        // docs:end
    }

    func testInvalidRecordType() throws {
        // docs:start:invalid-record-type
        struct Invalid: Record {
            var id = UUID()
            var direction: Direction
        }
        // "0" is not a valid value for this enum
        enum Direction: String, Codable {
            case up, down, left, right
        }
        XCTAssertThrowsError(
            // message: Error thrown from Direction.init(from:) ... Cannot initialize
            //          Direction from invalid String value 0
            try database.collection(Invalid.self)
        )
        // docs:end

        assertErrorMessage(
            try database.collection(Invalid.self),
            contains: "Error thrown from Direction.init(from:)")
        assertErrorMessage(
            try database.collection(Invalid.self),
            contains: "Cannot initialize Direction from invalid String value")
    }

    func testAddSupportForInvalidRecordType() throws {
        struct Fixed: Record {
            var id = UUID()
            var direction: Direction
        }
        XCTAssertNoThrow(
            try database.collection(Fixed.self)
        )
    }

    func testUseCustomCollation() throws {
        // docs:start:custom-collation-use
        let results = try employees
            .all()
            .orderBy(\.name, collation: .byLength)
            .fetchMany()
        // docs:end

        _ = results
    }

    func testUseCustomCollationAnnotation() throws {
        // docs:start:custom-collation-annotation-use
        struct Book: Record {
            var id = UUID()
            @CollateByLength var name: String
        }
        let books = try database.collection(Book.self)
        let results = try books.all().orderBy(\.name).fetchMany()
        //  ^^ results sorted by your custom collation
        // docs:end

        _ = results
    }

    func testRegisterCustomCollation() throws {
        try employees.insert([
            Employee(name: "aaa", salary: 123),
            Employee(name: "a", salary: 12),
            Employee(name: "cccc", salary: 1234),
            Employee(name: "bbb", salary: 1234)
        ])

        // docs:start:custom-collation-register
        let results = try employees
            .filter("""
                \(\.name) COLLATE \(.byLength) = CAST(\(\.salary) AS TEXT) COLLATE \(.byLength)
            """)
            .fetchMany()
        //  ^^ Select employees whose name is the same number of characters as the
        //     of digits in their Salary. Hey it seems like an odd feature but I'm
        //     sure the analysts know what they're doing when they asked for it?
        // docs:end

        XCTAssertEqual(results.map(\.name), ["aaa", "cccc"])
    }

    func testTransaction() throws {
        let database = db!
        struct Account: Record {
            var id: Int
            var balance: Int
        }
        try database.collection(Account.self).insert([
            Account(id: 1, balance: 100),
            Account(id: 2, balance: 0)
        ])
        // docs:start:database-transaction
        let accounts = try database.collection(Account.self)
        try database.write {
            guard var account1 = try accounts.filter(id: 1).fetchOne(),
                  var account2 = try accounts.filter(id: 2).fetchOne() else {
                throw MyError("Could not load accounts")
            }
            // move 10p from account 1 to account 2 without allowing the balance to go negative
            let amountToMove = max(account1.balance, 10)
            account1.balance -= amountToMove
            account2.balance += amountToMove
            try accounts.save(account1)
            try accounts.save(account2)
        }
        // docs:end
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
    func filter<Value: Codable>(_ property: KeyPath<Row, Value>, isEven: Bool) -> QueryBuilder<Row> {
        return filter("\(property) % 2 == \(isEven ? 0 : 1)")
    }
}
// docs:end

// docs:start:custom-collation
extension Collation {
    /// Ignore string content and sort by length
    static let byLength = Collation("byLength") { (lhs, rhs) in
        if lhs.count == rhs.count {
            return .orderedSame
        }
        return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
    }
}
// docs:end

// docs:start:custom-collation-annotation
@propertyWrapper
struct CollateByLength<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public static var propertyConfig: PropertyConfig {
        return .collation(.byLength)
    }
}
// docs:end
