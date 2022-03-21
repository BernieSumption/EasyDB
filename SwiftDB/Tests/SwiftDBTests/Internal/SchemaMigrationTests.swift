import XCTest
@testable import SwiftDB

class SchemaMigrationTests: XCTestCase {
    
    var c: Connection!
    var sm: SchemaMigration!

    override func setUpWithError() throws {
        c = try Connection(path: ":memory:")
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
                Index.Part(["d"], .ascending)
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
                Index.Part(["c"])
            ])
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c", "foo-d-asc"]
        )
        
        // add an index on another table
        try sm.ensureTableExists(table: "bar", columns: ["x", "y"])
        try sm.addIndex(
            table: "bar",
            Index([
                Index.Part(["x"]),
                Index.Part(["y"], .descending)
            ])
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c", "foo-d-asc"]
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["bar-x-y-desc"]
        )
        
        // drop an index
        try sm.dropIndex(name: "foo-d-asc")
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-c"]
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
                    Index.Part(["x"])
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
                    Index.Part(["b"], .ascending)
                ]),
                Index([
                    Index.Part(["b"]),
                    Index.Part(["a"], .descending)
                ]),
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-b-asc", "foo-b-a-desc"])
        
        // remove "ascending" from "b" (should create a new index)
        try sm.migrateIndices(
            table: "foo",
            indices: [
            Index([
                Index.Part(["b"])
            ]),
            Index([
                Index.Part(["b"]),
                Index.Part(["a"], .descending)
            ]),
        ])
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["foo-b", "foo-b-a-desc"])
        
        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"])
                ])
            ])
        XCTAssertEqual(try sm.getIndexNames(table: "foo"), ["foo-c"])
                                                      
        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"])
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
        let tableName = "special\" -- ch.ar;[s"
        let columnName = "w! -- \"onk;"
        
        try sm.ensureTableExists(table: tableName, columns: [columnName])
        XCTAssertEqual(try sm.getColumns(table: tableName) ,[columnName])
        
        // new set of indices
        try sm.migrateIndices(
            table: tableName,
            indices: [
                Index([
                    Index.Part([columnName])
                ])
            ])
        XCTAssertEqual(
            try sm.getIndexNames(table: tableName),
            ["\(tableName)-" + columnName])
    }
}
