import XCTest
@testable import SwiftDB

class ResultCodeTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual("\(ResultCode.OK)", "0 (not an error)")
        XCTAssertEqual("\(ResultCode.IOERR)", "10 (disk I/O error)")
    }
}
