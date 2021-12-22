import XCTest

@testable import SwiftDB

final class DiscriminationTests: XCTestCase {
    func testOnePropertyOfEachType() throws {
        let cycle = try Discrimination(OnePropertyOfEachType.self)
        XCTAssertEqual(cycle.instances, [])
    }
    struct OnePropertyOfEachType: Decodable, Equatable {
        let a: Bool
        let b: String
    }

    func testTwoBools() throws {
        let cycle = try Discrimination(TwoBools.self)
        XCTAssertEqual(
            cycle.instances, [TwoBools(a: false, b: true)])
    }
    struct TwoBools: Decodable, Equatable {
        let a: Bool, b: Bool
    }

    func testThreeBools() throws {
        let cycle = try Discrimination(ThreeBools.self)
        XCTAssertEqual(
            cycle.instances,
            [
                ThreeBools(a: false, b: true, c: false),
                ThreeBools(a: false, b: false, c: true),
            ])
    }
    struct ThreeBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool
    }

    func testFiveBools() throws {
        let cycle = try Discrimination(FiveBools.self)
        XCTAssertEqual(
            cycle.instances,
            [
                FiveBools(a: false, b: true, c: false, d: true, e: false),
                FiveBools(a: false, b: false, c: true, d: true, e: false),
                FiveBools(a: false, b: false, c: false, d: false, e: true),
            ])
    }
    struct FiveBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool, d: Bool, e: Bool
    }

    func testMixedBoolsAndInts() throws {
        let cycle = try Discrimination(Mixed.self)
        XCTAssertEqual(
            cycle.instances,
            [
                Mixed(b1: false, b2: true, b3: false, i1: 0, i2: 1, i3: 2, i4: 3),
                Mixed(b1: false, b2: false, b3: true, i1: 0, i2: 0, i3: 0, i4: 0),
            ])
    }
    struct Mixed: Decodable, Equatable {
        let b1: Bool, b2: Bool, b3: Bool
        let i1: Int, i2: Int, i3: Int, i4: Int
    }

    // TODO one bool = []
}
