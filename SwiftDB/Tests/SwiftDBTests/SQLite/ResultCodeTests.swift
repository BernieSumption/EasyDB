import XCTest
@testable import SwiftDB

class ResultCodeTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual("\(ResultCode.SQLITE_OK)", "0 (not an error)")
        XCTAssertEqual("\(ResultCode.SQLITE_IOERR)", "10 (disk I/O error)")
    }
}
