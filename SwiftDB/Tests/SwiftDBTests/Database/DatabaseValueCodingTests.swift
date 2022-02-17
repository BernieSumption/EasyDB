import XCTest
@testable import SwiftDB

class DatabaseValueCodingTests: XCTestCase {
    
    func testRoundTrip<T: Codable & Equatable>(_ value: T, _ expected: DatabaseValue) throws {
        let encoded = try DatabaseValueEncoder.encode(value)
        XCTAssertEqual(encoded, expected)
        let decoded = try DatabaseValueDecoder.decode(T.self, from: encoded)
        XCTAssertEqual(decoded, value)
    }
    
    func testTypeAndOptionals<T: Codable & Equatable>(_ value: T, _ expected: DatabaseValue) throws {
        try testRoundTrip(value, expected)
        let optionalPresent: T? = value
        try testRoundTrip(optionalPresent, expected)
        let optionalAbsent: T? = nil
        try testRoundTrip(optionalAbsent, .null)
        let optional2Present: T?? = value
        try testRoundTrip(optional2Present, expected)
        let optional2Absent: T?? = nil
        try testRoundTrip(optional2Absent, .null)
    }

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
    
    func testEncodeUUID() throws {
        let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        try testRoundTrip(uuid, .text("00000000-0000-0000-0000-000000000001"))
    }
    
    func testEncodeDate() throws {
        let uuid = Date(timeIntervalSinceReferenceDate: 20)
        try testRoundTrip(uuid, .text("2001-01-01T00:00:20Z"))
    }
    
    func testEncodeData() throws {
        let data = Data(repeating: 12, count: 1)
        try testRoundTrip(data, .blob(data))
    }
}
