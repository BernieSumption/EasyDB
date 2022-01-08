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
            ["swiftdb_column_d_asc"]
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
            ["swiftdb_column_c", "swiftdb_column_d_asc"]
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
            ["swiftdb_column_c", "swiftdb_column_d_asc"]
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["swiftdb_column_x_column_y_desc"]
        )
        
        // drop an index
        try sm.dropIndex(table: "foo", name: "swiftdb_column_d_asc")
        XCTAssertEqual(
            try sm.getIndexNames(table: "foo"),
            ["swiftdb_column_c"]
        )
        XCTAssertEqual(
            try sm.getIndexNames(table: "bar"),
            ["swiftdb_column_x_column_y_desc"]
        )
    }
    
    func testIndexMigration() throws {
        try sm.ensureTableExists(table: "foo", columns: ["a", "b", "c"])
        
        try sm.ensureTableExists(table: "bar", columns: ["x", "y"])
        
        try sm.migrateIndices(
            table: "bar",
            indices: [
                Index([
                    Index.Part(["x"]),
                    Index.Part(["x"])
                ])
            ])
        
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
            ["swiftdb_column_b_asc", "swiftdb_column_b_column_a_desc"])
        
        // remove "ascending" from "b" (should create a new index
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
            ["swiftdb_column_b", "swiftdb_column_b_column_a_desc"])
        
        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"])
                ])
            ])
        XCTAssertEqual(try sm.getIndexNames(table: "foo"), ["swiftdb_column_c"])
                                                      
        // new set of indices
        try sm.migrateIndices(
            table: "foo",
            indices: [
                Index([
                    Index.Part(["c"])
                ])
            ])
        XCTAssertEqual(try sm.getIndexNames(table: "foo"), ["swiftdb_column_c"])
        
        XCTAssertEqual(try sm.getIndexNames(table: "bar"), ["swiftdb_column_x_column_x"])
    }
}
