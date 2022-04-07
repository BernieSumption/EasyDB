import XCTest

@testable import SwiftDB

class TypeMetadataTests: XCTestCase {

    func testCollateMetadata() throws {
        let metadata = try MultifariousDecoder.metadata(for: CollateMetadata.self)
        XCTAssertEqual(
            metadata.getPropertyConfigs("foo"),
            [.collation(.caseInsensitive)])
    }

    struct CollateMetadata: Codable {
        @CollateCaseInsensitive
        var foo: Int
    }

    struct CollateMetadata2: Codable {
        @CollateCaseInsensitive
        private(set) var foo: Int
    }
}
