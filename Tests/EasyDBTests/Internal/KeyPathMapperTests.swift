import XCTest

@testable import EasyDB

class KeyPathMapperTests: XCTestCase {

    func testFlat() throws {
        let mapper = try KeyPathMapper.forType(Flat.self)
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

    func testNested() throws {
        let mapper = try KeyPathMapper.forType(Nested.self)
        XCTAssertEqual(try mapper.propertyPath(for: \.s1), ["s1"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s1.b), ["s1", "b"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s1.s12), ["s1", "s12"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s1.s12.f), ["s1", "s12", "f"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s1.s12.s23), ["s1", "s12", "s23"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s1.s12.s23.b), ["s1", "s12", "s23", "b"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s2), ["s2"])
        XCTAssertEqual(try mapper.propertyPath(for: \.s3), ["s3"])
    }
    struct Nested: Codable, Equatable {
        let s1: Sub1
        let s2: Sub2?
        let s3: Sub3

        struct Sub1: Codable, Equatable {
            let b: Bool
            let s12: Sub2
        }

        struct Sub2: Codable, Equatable {
            let f: Float
            let s23: Sub3
        }

        struct Sub3: Codable, Equatable {
            let b: Decimal
        }
    }

    func testArrays() throws {
        let mapper = try KeyPathMapper.forType(Arrays.self)
        XCTAssertEqual(try mapper.propertyPath(for: \.array), ["array"])
        XCTAssertEqual(try mapper.propertyPath(for: \.sub), ["sub"])
        XCTAssertEqual(try mapper.propertyPath(for: \.sub.b), ["sub", "b"])
        XCTAssertEqual(try mapper.propertyPath(for: \.subs), ["subs"])
    }
    struct Arrays: Codable, Equatable {
        let array: [Int]
        let sub: Sub
        let subs: [Sub]

        struct Sub: Codable, Equatable {
            let b: [Bool]
        }
    }

    func testDictionaries() throws {
        let mapper = try KeyPathMapper.forType(Dictionaries.self)
        XCTAssertEqual(try mapper.propertyPath(for: \.dict), ["dict"])
        XCTAssertEqual(try mapper.propertyPath(for: \.sub), ["sub"])
        XCTAssertEqual(try mapper.propertyPath(for: \.sub.b), ["sub", "b"])
        XCTAssertEqual(try mapper.propertyPath(for: \.keys), ["keys"])
    }
    struct Dictionaries: Codable, Equatable {
        let dict: [Int: String]
        let sub: Sub
        let keys: [Key: String]

        struct Sub: Codable, Equatable {
            let b: [Bool: [String: Int]]
        }

        struct Key: Codable, Hashable {
            let a: String
            let b: Bool
        }
    }

    func testCodingKeys() throws {
        let mapper = try KeyPathMapper.forType(WithCustomNames.self)
        XCTAssertEqual(try mapper.propertyPath(for: \.a), ["foo"])
    }
    struct WithCustomNames: Codable {
        let a: String

        enum CodingKeys: String, CodingKey {
            case a = "foo"
        }
    }

    func testCaching() throws {
        XCTAssertTrue(try KeyPathMapper.forType(Flat.self) === KeyPathMapper.forType(Flat.self))
    }
}
