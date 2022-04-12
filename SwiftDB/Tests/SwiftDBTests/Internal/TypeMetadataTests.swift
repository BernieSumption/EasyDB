import XCTest

@testable import SwiftDB

class TypeMetadataTests: XCTestCase {

    func testDefaultMetadata() throws {
        XCTAssertEqual(
            try combineConfigs([]),
            .init(collation: .string, index: nil))
    }

    func testCollateMetadata() throws {
        XCTAssertEqual(
            try combineConfigs([
                .collation(.caseInsensitive)
            ]),
            .init(collation: .caseInsensitive, index: nil))
    }

    func testCollateAndIndex() throws {
        XCTAssertEqual(
            try combineConfigs([
                .collation(.caseInsensitive),
                .index(unique: true)
            ]),
            .init(collation: .caseInsensitive, index: .unique))

        XCTAssertEqual(
            try combineConfigs([
                .index(unique: true),
                .collation(.caseInsensitive)
            ]),
            .init(collation: .caseInsensitive, index: .unique))

        XCTAssertEqual(
            try combineConfigs([
                .collation(.caseInsensitive),
                .index(unique: false)
            ]),
            .init(collation: .caseInsensitive, index: .regular))

        XCTAssertEqual(
            try combineConfigs([
                .index(unique: false),
                .collation(.caseInsensitive)
            ]),
            .init(collation: .caseInsensitive, index: .regular))
    }

    func testErrorOnMultipleCollationAnnotations() {
        assertErrorMessage(
            try combineConfigs([
                .collation(.caseInsensitive),
                .collation(.binary)
            ]),
            contains: "Multiple collations specified for myProperty - caseInsensitive then binary")
    }
}

func combineConfigs(_ configs: [PropertyConfig], isId: Bool = false) throws -> CombinedPropertyConfig {
    let metadata = TypeMetadata()
    try metadata.startTopLevelProperty(propertyName: "myProperty")
    for config in configs {
        try metadata.addPropertyConfig(config)
    }
    return try metadata.getCombinedConfig("myProperty", isId: isId)
}
