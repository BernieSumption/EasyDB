import XCTest

@testable import SwiftDB

class TypeMetadataTests: XCTestCase {

    func testCollateMetadata() throws {
        let metadata = try MultifariousDecoder.metadata(for: CollateMetadata.self)
        XCTAssertEqual(metadata.getPropertyConfigs("foo"), [.collation(.caseInsensitive), .collation(.caseInsensitive)])
    }

    struct CollateMetadata: Codable {
        @Collate @Collate var foo: Int
    }
}
