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
            contains: "Error decoding property foo: duplicate configuration property wrapper @NotUnique encountered")
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

        // @NotUnique var id
        XCTAssertEqual(
            try combineConfigs([
                .noDefaultUniqueId
            ], isId: true).index,
            nil)

        // @NotUnique @Index var id
        XCTAssertEqual(
            try combineConfigs([
                .noDefaultUniqueId,
                .index(unique: false)
            ], isId: true).index,
            .regular)
    }

    func testErrorWhenNotUniqueAppliedToNonId() throws {
        assertErrorMessage(
            try MultifariousDecoder.metadata(for: ErrorWhenNotUniqueAppliedToNonId.self).getCombinedConfig("foo", isId: false),
            contains: "@NotUnique can only be applied to the id property of an Identifiable type")
    }
    struct ErrorWhenNotUniqueAppliedToNonId: Codable {
        @NotUnique var foo: Int
    }

    func testErrorOnConflictingAnnotations() {
        assertErrorMessage(
            // @NotUnique @Unique
            try combineConfigs([
                .noDefaultUniqueId,
                .index(unique: true)
            ], isId: true),
            contains: "both @NotUnique and @Unique specified")

        assertErrorMessage(
            // @Unique @NotUnique
            try combineConfigs([
                .index(unique: true),
                .noDefaultUniqueId
            ], isId: true),
            contains: "both @Unique and @NotUnique specified")
    }

    func testJSONCodingWithAnnotations() throws {
        let instance = JSONCodingWithAnnotations(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            x: 3,
            f16: 4.5,
            foo: "bar",
            sub: .init(s: "s!"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(instance)
        let json = String(decoding: jsonData, as: UTF8.self)

        XCTAssertEqual(
            json,
            """
            {
              "foo" : "bar",
              "id" : "00000000-0000-0000-0000-000000000001",
              "f16" : 4.5,
              "x" : 3,
              "sub" : {
                "s" : "s!"
              }
            }
            """
        )

        let decoded = try JSONDecoder().decode(JSONCodingWithAnnotations.self, from: jsonData)

        XCTAssertEqual(decoded, instance)
    }
    struct JSONCodingWithAnnotations: Codable, Identifiable, Equatable {
        @NotUnique @Index var id: UUID
        @Unique var x: Int
        var f16: Float16
        @CollateCaseInsensitive var foo: String
        @CollateBinary var sub: Sub

        struct Sub: Codable, Equatable {
            let s: String
        }
    }

    func testFoo() {
        print(MemoryLayout<Foo>.size)
    }
}

struct Foo {
    @Wrapper
    var sub: P
}

protocol P {
}

@propertyWrapper
public class Wrapper<Value>: P {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        print("Init!", wrappedValue)
        self.wrappedValue = wrappedValue
    }
}

struct Sub {
    let i1: Int
    let i2: Int
    let i3: Int
    let i4: Int
    let i5: Int
    let i6: Int
    let i7: Int
    let i8: Int
    let i9: Int
    let i10: Int
}

func combineConfigs(_ configs: [PropertyConfig], isId: Bool = false) throws -> CombinedPropertyConfig {
    let metadata = TypeMetadata()
    try metadata.startTopLevelProperty(propertyName: "myProperty")
    for config in configs {
        try metadata.addPropertyConfig(config)
    }
    return try metadata.getCombinedConfig("myProperty", isId: isId)
}
