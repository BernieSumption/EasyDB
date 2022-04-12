import XCTest

@testable import SwiftDB

class TypeMetadataTests: XCTestCase {

    func testSingleAnnotation() throws {
        XCTAssertEqual(
            try MultifariousDecoder.metadata(for: SingleAnnotation.self).getConfigs("x"),
            [
                .index(unique: true)
            ])
    }
    struct SingleAnnotation: Codable {
        @Unique var x: Int
    }

    func testTwoAnnotations() throws {
        XCTAssertEqual(
            try MultifariousDecoder.metadata(for: TwoAnnotations.self).getConfigs("x"),
            [
                .index(unique: false),
                .noDefaultUniqueId
            ])
    }
    struct TwoAnnotations: Codable {
        @Index @NotUnique var x: Int
    }

    func testTwoAnnotationsOnSub() throws {
        XCTAssertEqual(
            try MultifariousDecoder.metadata(for: TwoAnnotationsOnSub.self).getConfigs("sub"),
            [
                .index(unique: false),
                .noDefaultUniqueId
            ])
    }
    struct TwoAnnotationsOnSub: Codable {
        @Index @NotUnique var sub: Sub

        struct Sub: Codable, Equatable {
            var foo: String
        }
    }

    func testErrorOnSubStructAnnotation() throws {
        assertErrorMessage(
            try MultifariousDecoder.metadata(for: ErrorOnSubStructAnnotation.self),
            contains: "Error decoding property sub.foo: configuration annotation @Unique encountered below the top level type")
    }

    struct ErrorOnSubStructAnnotation: Codable {
        @Index var sub: Sub

        struct Sub: Codable, Equatable {
            @Unique var foo: String
        }
    }

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
