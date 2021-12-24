import XCTest

@testable import SwiftDB

final class MultifariousTests: XCTestCase {
    func testTwoBools() throws {
        let instances = try Multifarious.instances(for: TwoBools.self)
        XCTAssertEqual(
            instances, [TwoBools(a: false, b: true)])
    }
    struct TwoBools: Decodable, Equatable {
        let a: Bool, b: Bool
    }

    func testThreeBools() throws {
        let instances = try Multifarious.instances(for: ThreeBools.self)
        XCTAssertEqual(
            instances,
            [
                ThreeBools(a: false, b: true, c: false),
                ThreeBools(a: false, b: false, c: true),
            ])
    }
    struct ThreeBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool
    }

    func testFiveBools() throws {
        let instances = try Multifarious.instances(for: FiveBools.self)
        XCTAssertEqual(
            instances,
            [
                FiveBools(a: false, b: true, c: false, d: true, e: false),
                FiveBools(a: false, b: false, c: true, d: true, e: false),
                FiveBools(a: false, b: false, c: false, d: false, e: true),
            ])
    }
    struct FiveBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool, d: Bool, e: Bool
    }

    private let uuid0 = UUID(uuid: (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0))
    private let uuid1 = UUID(uuid: (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1))

    private let date0 = Date(timeIntervalSince1970: 1_234_567_890)
    private let date1 = Date(timeIntervalSince1970: 1_234_567_891)

    private let data0 = Data(repeating: 9, count: 10)
    private let data1 = Data(repeating: 8, count: 10)

    func testMixed() throws {
        let instances = try Multifarious.instances(for: Mixed.self)
        XCTAssertEqual(
            instances,
            [
                Mixed(
                    id: uuid0, id2: uuid1,
                    date: date0, date2: date1,
                    data: data0, data2: data1,
                    s1: "a", s2: "b", b1: false, b2: true, b3: false, n1: 0, n2: 1, n3: 2, n4: 3,
                    n5: 4, n6: 5, n7: 6, n8: 7, n9: 8, n10: 9, n11: 10, n12: 11, n13: 12, n14: 100_000, n15: 100_001),
                Mixed(
                    id: uuid0, id2: uuid0,
                    date: date0, date2: date0,
                    data: data0, data2: data0,
                    s1: "a", s2: "a", b1: false, b2: false, b3: true, n1: 0, n2: 0, n3: 0, n4: 0,
                    n5: 0, n6: 0, n7: 0, n8: 0, n9: 0, n10: 0, n11: 0, n12: 0, n13: 0, n14: 100_000, n15: 100_000),
            ])
    }
    struct Mixed: Decodable, Equatable {
        let id: UUID, id2: UUID
        let date: Date, date2: Date
        let data: Data, data2: Data
        let s1: String, s2: String
        let b1: Bool, b2: Bool, b3: Bool
        let n1: Double
        let n2: Float
        let n3: Int
        let n4: Int8
        let n5: Int16
        let n6: Int32
        let n7: Int64
        let n8: UInt
        let n9: UInt8
        let n10: UInt16
        let n11: UInt32
        let n12: UInt64
        let n13: UInt64
        let n14: Decimal
        let n15: Decimal
    }
    
    func testNested() throws {
        let instances = try Multifarious.instances(for: Nested.self)
        XCTAssertEqual(instances, [
            .init(
                b: false,
                s1: .init(
                    b: true,
                    o: .init(
                        b: false,
                        f: 0,
                        o: .init(b: 1)
                    )
                ),
                s2: .init(
                    b: true,
                    f: 2,
                    o: .init(b: 3)
                ),
                s3: .init(b: 4)
            )
        ])
    }
    struct Nested: Codable, Equatable {
        let b: Bool?
        let s1: Sub1
        let s2: Sub2
        let s3: Sub3
        
        struct Sub1: Codable, Equatable {
            let b: Bool
            let o: Sub2
        }
        
        struct Sub2: Codable, Equatable {
            let b: Bool
            let f: Float
            let o: Sub3
        }
        
        struct Sub3: Codable, Equatable {
            let b: Decimal
        }
    }
}
