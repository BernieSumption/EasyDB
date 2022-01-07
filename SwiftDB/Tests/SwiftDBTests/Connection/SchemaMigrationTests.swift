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
        try sm.createIfNotExists(table: "foo", columns: ["a", "b"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "b"])
        
        try sm.addColumn(table: "foo", column: "f")
        try sm.addColumn(table: "foo", column: "e")
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "b", "e", "f"])
        
        try sm.dropColumn(table: "foo", column: "b")
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "e", "f"])
    }
    
    func testTableMigration() throws {
        try sm.migrate(table: "foo", columns: ["lala", "bar"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["bar", "lala"])
        
        try c.execute(sql: "INSERT INTO foo (lala, bar) VALUES (1, 2)")
        
        // add and remove
        try sm.migrate(table: "foo", columns: ["a", "bar", "cat"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["a", "bar", "cat"])
        XCTAssertEqual( // existing data not removed
            try c.execute([String: Int?].self, sql: "SELECT * FROM foo"),
            ["a": nil, "bar": 2, "cat": nil])
        
        // change to a totally different set
        try sm.migrate(table: "foo", columns: ["l"])
        XCTAssertEqual(try sm.getColumns(table: "foo"), ["l"])
    }
    
    func testIndexModifications() throws {
        try sm.createIfNotExists(table: "foo", columns: ["c", "d"])
        try sm.addIndex(table: "foo", column: .init("c", direction: .ascending))
        
    }
}
