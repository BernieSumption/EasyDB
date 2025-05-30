import XCTest

@testable import EasyDB

class ResultCodeTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual("\(ResultCode.OK)", "SQLITE_OK (not an error)")
        XCTAssertEqual("\(ResultCode.IOERR)", "SQLITE_IOERR (disk I/O error)")
    }
}
