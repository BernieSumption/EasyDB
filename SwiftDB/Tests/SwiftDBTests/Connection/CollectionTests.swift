import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db = Database(path: ":memory:")

    func testSimpleCodable() throws {
        let c = try db.collection(Row.self)
        try c.insert(Row(i: 4))
        
        Next up: c.select().fetchAll()
        
        struct Row: Codable {
            let i: Int
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
