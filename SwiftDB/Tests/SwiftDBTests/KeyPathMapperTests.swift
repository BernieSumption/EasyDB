import XCTest

@testable import SwiftDB

class KeyPathMapperTests: XCTestCase {

    func testFlat() throws {
        let mapper = try KeyPathMapper(Flat.self)
        XCTAssertEqual(try mapper.propertyPath(for: \.a), ["a"])
        XCTAssertEqual(try mapper.propertyPath(for: \.b), ["b"])
        XCTAssertEqual(try mapper.propertyPath(for: \.c), ["c"])
        XCTAssertEqual(try mapper.propertyPath(for: \.d), ["d"])
    }
    struct Flat: Codable {
        let a: Int
        let b: Bool
        let c: Bool
        let d: Bool
    }
}
