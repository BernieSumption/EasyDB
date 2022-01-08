import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db = Database(path: ":memory:")

    func testSimpleCodable() throws {
        let c = try db.collection(Row.self)
        
        Next up: insert and retrieve!
        
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
