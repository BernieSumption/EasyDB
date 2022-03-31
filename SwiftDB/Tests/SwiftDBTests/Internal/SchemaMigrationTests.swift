import XCTest
@testable import SwiftDB

class SchemaMigrationTests: SwiftDBTestCase {

    var c: Connection!
    var sm: SchemaMigration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        c = try db.getConnection()
        sm = SchemaMigration(connection: c)
    }

    func testTableModification() throws {
        try sm.ensureTableExists(table: "foo", columns: ["a", "b"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "b"])

        try sm.addColumn(table: "foo", column: "f")
        try sm.addColumn(table: "foo", column: "e")
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "b", "e", "f"])

        try sm.dropColumn(table: "foo", column: "b")
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "e", "f"])
    }

    func testTableMigration() throws {
        try sm.migrateColumns(table: "foo", columns: ["lala", "bar"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["bar", "lala"])

        try c.execute(sql: "INSERT INTO foo (lala, bar) VALUES (1, 2)")

        // add and remove
        try sm.migrateColumns(table: "foo", columns: ["a", "bar", "cat"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "bar", "cat"])
        XCTAssertEqual( // existing data not removed
            try c.execute([String: Int?].self, sql: "SELECT * FROM foo"),
            ["a": nil, "bar": 2, "cat": nil])

        // change to a totally different set
        try sm.migrateColumns(table: "foo", columns: ["l"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["l"])

        try sm.migrateColumns(table: "bar", columns: ["lala", "quux"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["l"])
        XCTAssertEqual(try sm.getColumns(table: "bar"), ["lala", "quux"])
    }

    func testIndexModifications() throws {
        try sm.ensureTableExists(table: "foo", columns: ["c", "d", "e"])

        // Add an index
        try sm.addIndex(
            table: "foo",
            Index([
                Index.Part(["d"], collation: nil, .ascending)
            ])
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-d-asc"]
        )

        // add another
        try sm.addIndex(
            table: "foo",
            Index([
                Index.Part(["c"], collation: .caseInsensitive)
            ])
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c-caseInsensitive", "foo-d-asc"]
        )

        // add an index on another table
        try sm.ensureTableExists(table: "bar", columns: ["x", "y"])
        try sm.addIndex(
            table: "bar",
            Index([
                Index.Part(["x"], collation: nil),
                Index.Part(["y"], collation: nil, .descending)
            ])
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c-caseInsensitive", "foo-d-asc"]
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["bar-x-y-desc"]
        )

        // drop an index
        try sm.dropIndex(name: "foo-d-asc")
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c-caseInsensitive"]
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["bar-x-y-desc"]
        )
    }

    func testIndexMigration() throws {
        try sm.ensureTableExists(table: "foo", columns: ["a", "b", "c"])

        try sm.ensureTableExists(table: "bar", columns: ["x", "y"])

        // create one index
        try sm.migrateIndices(
            table: "bar",
            indices: [
                Index([
                    Index.Part(["x"], collation: nil)
                ])
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["bar-x"])

        // create two indices on another table
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["b"], collation: nil, .ascending)
                ]),
                Index([
                    Index.Part(["b"], collation: nil),
                    Index.Part(["a"], collation: nil, .descending)
                ])
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-b-a-desc", "foo-b-asc"])

        // remove "ascending" from "b" (should create a new index)
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["b"], collation: nil)
                ]),
                Index([
                    Index.Part(["b"], collation: nil),
                    Index.Part(["a"], collation: nil, .descending)
                ])
        ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-b", "foo-b-a-desc"])

        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"], collation: nil)
                ])
            ])
        XCTAssertEqual(try sm.getIndexNames(table: "foo"), ["foo-c"])

        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"], collation: nil)
                ])
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c"])
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["bar-x"])
    }

    func testQuotedNames() throws {
        let tableName = "speci`al\" -- ch.ar;[s"
        let columnName = "w! -- \"on`k;"

        db.logSQL = .print

        try sm.ensureTableExists(table: tableName, columns: [columnName])
        XCTAssertEqual(try sm.getColumns(table: tableName), [columnName])

        // new set of indices
        try sm.migrateIndices(
            table: tableName,
            indices: [
                Index([
                    Index.Part([columnName], collation: nil)
                ])
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: tableName),
            ["\(tableName)-" + columnName])
    }
}
