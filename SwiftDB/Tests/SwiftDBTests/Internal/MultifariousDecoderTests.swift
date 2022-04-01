import XCTest

@testable import SwiftDB

final class MultifariousDecoderTests: XCTestCase {

    func testTwoBools() throws {
        let instances = try MultifariousDecoder.instances(for: TwoBools.self)
        XCTAssertEqual(
            instances, [TwoBools(a: false, b: true)])
    }
    struct TwoBools: Decodable, Equatable {
        let a: Bool, b: Bool
    }

    func testThreeBools() throws {
        let instances = try MultifariousDecoder.instances(for: ThreeBools.self)
        XCTAssertEqual(
            instances,
            [
                ThreeBools(a: false, b: true, c: false),
                ThreeBools(a: false, b: false, c: true)
            ])
    }
    struct ThreeBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool
    }

    func testFiveBools() throws {
        let instances = try MultifariousDecoder.instances(for: FiveBools.self)
        XCTAssertEqual(
            instances,
            [
                FiveBools(a: false, b: true, c: false, d: true, e: false),
                FiveBools(a: false, b: false, c: true, d: true, e: false),
                FiveBools(a: false, b: false, c: false, d: false, e: true)
            ])
    }
    struct FiveBools: Decodable, Equatable {
        let a: Bool, b: Bool, c: Bool, d: Bool, e: Bool
    }

    private let uuid0 = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    private let uuid1 = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    private let date0 = Date(timeIntervalSince1970: 0)
    private let date1 = Date(timeIntervalSince1970: 1)

    private let data0 = Data(repeating: 0, count: 1)
    private let data1 = Data(repeating: 1, count: 1)

    func testMixed() throws {
        let instances = try MultifariousDecoder.instances(for: Mixed.self)
        XCTAssertEqual(
            instances,
            [
                Mixed(id: uuid0, s: "1", i: 0, d: 1),
                Mixed(id: uuid0, s: "0", i: 1, d: 1)
            ])
    }
    struct Mixed: Decodable, Equatable {
        let id: UUID
        let s: String
        let i: UInt16
        let d: Decimal
    }

    func testNested() throws {
        let instances = try MultifariousDecoder.instances(for: Nested.self)
        XCTAssertEqual(
            instances[0...1],
            [
                // first instance values run 0, 1, 0, 1 etc
                .init(
                    b: false,
                    s1: .init(
                        b: true,
                        o: .init(
                            b: false,
                            f: 1,
                            o: .init(b: 0)
                        )
                    ),
                    s2: .init(
                        b: true,
                        f: 0,
                        o: .init(b: 1)
                    ),
                    s3: .init(b: 0)
                ),
                // second instance values run 0, 0, 1, 1, 0, 0, 1, 1 etc
                .init(
                    b: false,
                    s1: .init(
                        b: false,
                        o: .init(
                            b: true,
                            f: 1,
                            o: .init(b: 0)
                        )
                    ),
                    s2: .init(
                        b: false,
                        f: 1,
                        o: .init(b: 1)
                    ),
                    s3: .init(b: 0)
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

    func testArrays() throws {
        let instances = try MultifariousDecoder.instances(for: Arrays.self)
        XCTAssertEqual(
            instances,
            [
                .init(
                    arr: [.init(b: false), .init(b: true)],
                    i: [0, 1]
                ),
                .init(
                    arr: [.init(b: false), .init(b: false)],
                    i: [1, 1]
                )
            ])
    }
    struct Arrays: Codable, Equatable {
        let arr: [Sub1]
        let i: [Int]

        struct Sub1: Codable, Equatable {
            let b: Bool
        }
    }

    func testDictionaries() throws {
        let instances = try MultifariousDecoder.instances(for: Dictionaries.self)
        XCTAssertEqual(
            instances,
            [
                .init(
                    sDict: ["0": .init(b: true)],
                    iDict: [0: 1]
                ),
                .init(
                    sDict: ["0": .init(b: false)],
                    iDict: [1: 1]
                )
            ])
    }
    struct Dictionaries: Codable, Equatable {
        let sDict: [String: Sub1]
        let iDict: [Int: Int]

        struct Sub1: Codable, Equatable {
            let b: Bool
        }
    }

    func testDateDictionaries() throws {
        let instances = try MultifariousDecoder.instances(for: [Date: Int].self)
        XCTAssertEqual(
            instances,
            [
                [Date(timeIntervalSince1970: 0): 1]
            ])
    }

    func testUUIDDictionaries() throws {
        let instances = try MultifariousDecoder.instances(for: [UUID: Int].self)
        XCTAssertEqual(
            instances,
            [
                [UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)): 1]
            ])
    }

    func testTopLevelScalar() throws {
        let instances = try MultifariousDecoder.instances(for: Int.self)
        XCTAssertEqual(instances, [0])
    }

    func testTopLevelArray() throws {
        let instances = try MultifariousDecoder.instances(for: [Int].self)
        XCTAssertEqual(instances, [[0, 1]])
    }

    func testWrappedError() throws {
        XCTAssertThrowsError(
            try MultifariousDecoder.instances(for: Tmp.self)
        ) { error in
            XCTAssertEqual(
                String(describing: error), "Error thrown from Sub(from: Decoder): my-error-message")
        }
    }
    struct Tmp: Codable {
        let s: Sub

        struct Sub: Codable {
            init(from: Decoder) throws {
                throw Err.error
            }
        }
        enum Err: Error, CustomStringConvertible {
            case error
            public var description: String {
                "my-error-message"
            }
        }

    }
}
