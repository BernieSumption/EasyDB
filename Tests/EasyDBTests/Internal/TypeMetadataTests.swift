import XCTest

@testable import EasyDB

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
                .collation(.caseInsensitive)
            ])
    }
    struct TwoAnnotations: Codable {
        @Index @CollateCaseInsensitive var x: Int
    }

    func testTwoAnnotationsOnSub() throws {
        XCTAssertEqual(
            try MultifariousDecoder.metadata(for: TwoAnnotationsOnSub.self).getConfigs("sub"),
            [
                .index(unique: false),
                .collation(.caseInsensitive)
            ])
    }
    struct TwoAnnotationsOnSub: Codable {
        @Index @CollateCaseInsensitive var sub: Sub

        struct Sub: Codable, Equatable {
            var foo: String
        }
    }

    func testErrorOnSubStructAnnotation() throws {
        assertErrorMessage(
            try MultifariousDecoder.metadata(for: ErrorOnSubStructAnnotation.self),
            contains: "Error decoding property sub.foo: configuration property wrapper @Unique encountered below the top level type")
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
            contains: "Error decoding property sub.foo: configuration property wrapper @Unique encountered below the top level type")
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
            contains: "Error decoding property foo: duplicate configuration property wrapper @Unique encountered")
    }
    struct ErrorOnDuplicateAnnotations: Codable {
        @Unique @Unique var foo: Int
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
        // var id with no property wrapper
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
    }

    func testJSONCodingWithAnnotations() throws {
        let instance = JSONCodingWithAnnotations(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            x: 3,
            f: 4.5,
            foo: "bar",
            sub: .init(s: "s!"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(instance)
        let json = String(decoding: jsonData, as: UTF8.self)

        XCTAssertEqual(
            json,
            """
            {
              "f" : 4.5,
              "foo" : "bar",
              "id" : "00000000-0000-0000-0000-000000000001",
              "sub" : {
                "s" : "s!"
              },
              "x" : 3
            }
            """
        )

        let decoded = try JSONDecoder().decode(JSONCodingWithAnnotations.self, from: jsonData)

        XCTAssertEqual(decoded, instance)
    }
    struct JSONCodingWithAnnotations: Codable, Identifiable, Equatable {
        @CollateCaseInsensitive @Index var id: UUID
        @Unique var x: Int
        var f: Float
        @CollateCaseInsensitive var foo: String
        @CollateBinary var sub: Sub

        struct Sub: Codable, Equatable {
            let s: String
        }
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
