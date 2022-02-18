import XCTest
@testable import SwiftDB

class DatabaseValueCodingTests: XCTestCase {
    
    func testEncodeBuiltInTypes() throws {
        try testTypeAndOptionals(Int8(-5), .int(-5))
        try testTypeAndOptionals(Int32(10), .int(10))
        try testTypeAndOptionals(UInt64(UInt64.max), .int(-1)) // unsigned 64 bit integer stored with overflow
        try testTypeAndOptionals(Float16(10.5), .double(10.5))
        try testTypeAndOptionals(Double(10.5), .double(10.5))
        try testTypeAndOptionals("foo", .text("foo"))
        try testTypeAndOptionals(["a", "b"], .text(#"["a","b"]"#))
        try testTypeAndOptionals(#"["a","b"]"#, .text(#"["a","b"]"#))
        try testTypeAndOptionals(["a": 1, "b": 2], .text(#"{"a":1,"b":2}"#))
        try testTypeAndOptionals(#"{"a":1,"b":2}"#, .text(#"{"a":1,"b":2}"#))
    }
    
    func testEncodeStructures() throws {
        try testStructure(Int8(-5), "-5")
        try testStructure(Int32(10), "10")
        try testStructure(UInt64(UInt64.max), "18446744073709551615") // unsigned 64 bit integer should not overflow in JSON
        try testStructure(Float16(10.5), "10.5")
        try testStructure(Double(10.5), "10.5")
        try testStructure("foo", #""foo""#)
        try testStructure(["a", "b"], #"["a","b"]"#)
        try testStructure(#"["a","b"]"#, #""[\"a\",\"b\"]""#)
        try testStructure(["a": 1, "b": 2], #"{"a":1,"b":2}"#)
        try testStructure(#"{"a":1,"b":2}"#, #""{\"a\":1,\"b\":2}""#)
    }
    
    func testEncodeUUID() throws {
        let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        try testBuiltInType(uuid, .text("00000000-0000-0000-0000-000000000001"))
        try testStructure(uuid, #""00000000-0000-0000-0000-000000000001""#)
    }
    
    func testEncodeDate() throws {
        let date = Date(timeIntervalSinceReferenceDate: 20)
        try testBuiltInType(date, .text("2001-01-01T00:00:20Z"))
        try testStructure(date, #""2001-01-01T00:00:20Z""#)
    }
    
    func testEncodeData() throws {
        let data = Data([0x12, 0x34])
        try testBuiltInType(data, .blob(data))
        try testStructure(data, #""EjQ=""#)
    }
    
}

extension DatabaseValueCodingTests {

    func testTypeAndOptionals<T: Codable & Equatable>(_ value: T, _ expected: DatabaseValue) throws {
        try testBuiltInType(value, expected)
        let optionalPresent: T? = value
        try testBuiltInType(optionalPresent, expected)
        let optionalAbsent: T? = nil
        try testBuiltInType(optionalAbsent, .null)
        let optional2Present: T?? = value
        try testBuiltInType(optional2Present, expected)
        let optional2Absent: T?? = nil
        try testBuiltInType(optional2Absent, .null)
    }

    func testBuiltInType<T: Codable & Equatable>(_ value: T, _ expected: DatabaseValue) throws {
        let encoded = try DatabaseValueEncoder.encode(value)
        XCTAssertEqual(encoded, expected)
        let decoded = try DatabaseValueDecoder.decode(T.self, from: encoded)
        XCTAssertEqual(decoded, value)
    }

    func testStructure<T: Codable & Equatable>(_ value: T, _ expected: String) throws {
        let sub = Sub(value)
        let encodedSub = try DatabaseValueEncoder.encode(sub)
        let expectedJSON = "{\"o2y\":\(expected),\"oy\":\(expected),\"v\":\(expected)}"
        XCTAssertEqual(encodedSub, .text(expectedJSON))
        let decodedSub = try DatabaseValueDecoder.decode(Sub<T>.self, from: encodedSub)
        XCTAssertEqual(decodedSub, sub)
    }
    struct Sub<T: Codable & Equatable>: Codable & Equatable {
        let v: T
        let oy: T?
        let on: T?
        let o2y: T??
        let o2n: T??
        init(_ value: T) {
            v = value
            oy = value
            on = nil
            o2y = value
            o2n = nil
        }
    }
}
