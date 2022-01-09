import XCTest
import SwiftDB

class CollectionTests: XCTestCase {
    
    var db = Database(path: ":memory:")

    func testSimpleCodable() throws {
        let c = try db.collection(Row.self)
        try c.insert(Row(i: 4))
        
        struct Row: Codable {
            let i: Int
        }
    }

}
