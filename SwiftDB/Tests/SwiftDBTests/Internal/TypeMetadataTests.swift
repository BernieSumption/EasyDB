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
        var sub: Sub

        struct Sub: Codable, Equatable {
            @Unique var foo: String
        }
    }

    func testErrorOnSubStructNestedAnnotation() throws {
        assertErrorMessage(
            try MultifariousDecoder.metadata(for: ErrorOnSubStructNestedAnnotation.self),
            contains: "Error decoding property sub.foo: configuration annotation @Unique encountered below the top level type")
    }
    struct ErrorOnSubStructNestedAnnotation: Codable {
        @Index var sub: Sub

        struct Sub: Codable, Equatable {
            @Unique var foo: String
        }
    }

    func testErrorOnDuplicateAnnotations() throws {
        assertErrorMessage(
            try MultifariousDecoder.metadata(for: ErrorOnDuplicateAnnotations.self),
            contains: "Error decoding property foo: duplicate configuration annotation @NotUnique encountered")
    }
    struct ErrorOnDuplicateAnnotations: Codable {
        @NotUnique @NotUnique var foo: Int
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

    func testUniqueBeatsIndex() {
        XCTAssertEqual(
            try combineConfigs([
                .index(unique: false),
                .index(unique: true)
            ]).index,
            .unique)

        XCTAssertEqual(
            try combineConfigs([
                .index(unique: true),
                .index(unique: false)
            ]).index,
            .unique)
    }

    func testUniqueId() {
        // var id with no annotation
        XCTAssertEqual(
            try combineConfigs([], isId: true).index,
            .unique)

        // @Index var id
        XCTAssertEqual(
            try combineConfigs([
                .index(unique: false)
            ], isId: true).index,
            .unique)

        // @Unique var id
        XCTAssertEqual(
            try combineConfigs([
                .index(unique: true)
            ], isId: true).index,
            .unique)

        // @NotUnique var id
        XCTAssertEqual(
            try combineConfigs([
                .noDefaultUniqueId
            ]).index,
            nil)

        // @NotUnique @Index var id
        XCTAssertEqual(
            try combineConfigs([
                .noDefaultUniqueId,
                .index(unique: false)
            ]).index,
            .regular)
    }

    func testErrorOnConflictingAnnotations() {
        assertErrorMessage(
            // @NotUnique @Unique
            try combineConfigs([
                .noDefaultUniqueId,
                .index(unique: true)
            ]),
            contains: "both @Unique and @NotUnique specified")

        assertErrorMessage(
            // @Unique @NotUnique
            try combineConfigs([
                .index(unique: true),
                .noDefaultUniqueId
            ]),
            contains: "both @Unique and @NotUnique specified")
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
