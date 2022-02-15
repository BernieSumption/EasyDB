import XCTest
@testable import SwiftDB

class ParameterValueEncoderTests: XCTestCase {
    
    func assertEncode<T: Encodable>(_ value: T, _ encoded: ParameterValue) {
        XCTAssertEqual(try ParameterValueEncoder.encode(value), encoded)
    }

    func testEncodeBuiltInTypes() {
        assertEncode(Int32(10), .int(10))
        assertEncode(UInt64(10), .int(10))
        assertEncode(Float16(10.5), .double(10.5))
        assertEncode(Double(10.5), .double(10.5))
        assertEncode("foo", .text("foo"))
        let optionalStringNil: String? = nil
        assertEncode(optionalStringNil, .null)
        let optionalStringPresent: String? = "here"
        assertEncode(optionalStringPresent, .text("here"))
        
        let optionalStringPresent2: Optional<String?> = "here"
        assertEncode(optionalStringPresent2, .text("here"))
        
        let optionalIntPresent: Int? = 2
        assertEncode(optionalIntPresent, .int(2))
    }
    
    func testEncodeUUID() {
        let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        assertEncode(uuid, .text("00000000-0000-0000-0000-000000000001"))
    }
    
    func testEncodeDate() {
        let uuid = Date(timeIntervalSinceReferenceDate: 20)
        assertEncode(uuid, .text("2001-01-01T00:00:20"))
    }
    
    func testEncodeData() {
        let data = Data(repeating: 12, count: 1)
        assertEncode(data, .blob(data))
    }
}
