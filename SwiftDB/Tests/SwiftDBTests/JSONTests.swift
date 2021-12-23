import XCTest

@testable import SwiftDB

class JSONTests: XCTestCase {

    func testParseSimpleValues() throws {
        XCTAssertEqual(try JSON(parsing: "1"), JSON.number(1))
        XCTAssertEqual(try JSON(parsing: "1.5"), JSON.number(1.5))
        XCTAssertEqual(try JSON(parsing: "true"), JSON.boolean(true))
        XCTAssertEqual(try JSON(parsing: "null"), JSON.null)
        XCTAssertEqual(try JSON(parsing: "\"wotcha\""), JSON.string("wotcha"))
        XCTAssertEqual(try JSON(parsing: "\"10\""), JSON.string("10"))
        XCTAssertEqual(try JSON(parsing: "[]"), JSON.array([]))
        XCTAssertEqual(try JSON(parsing: "{}"), JSON.object([:]))
    }

    func testParseNestedValues() throws {
        XCTAssertEqual(
            try JSON(
                parsing:
                    """
                    [
                        true,
                        1,
                        {"a": [4]},
                        [{"b": "5"}]
                    ]
                    """
            ),
            JSON.array([
                .boolean(true),
                .number(1),
                .object([
                    "a": .array([.number(4)])
                ]),
                .array([
                    .object(["b": .string("5")])
                ]),
            ])
        )
    }

    func testParseCodable() throws {
        XCTAssertEqual(
            try JSON(encoding: ParseCodable()),
            .object([
                "bool": .boolean(true),
                "object": .object(["i": .number(1)]),
                "arrayObjects": .array([
                    .object(["i": .number(2)])
                ]),
                "dict": .object([
                    "foo": .array([]),
                    "bar": .array([
                        .object(["i": .number(3)])
                    ]),
                ]),
            ])
        )
    }
    struct ParseCodable: Encodable {
        let bool = true
        let object = O(i: 1)
        let arrayObjects = [O(i: 2)]
        let dict: [String: [O]] = ["foo": [], "bar": [O(i: 3)]]

        struct O: Encodable {
            let i: Int
        }
    }

    func testPropertyPaths() throws {
        let json = try JSON(
            parsing:
                """
                {
                    "a": 1,
                    "b": 2,
                    "c": {
                        "c1": [{"c11": 4}],
                        "c2": {"c21": 4},
                    },
                    "d": ["4"]
                }
                """
        )
        XCTAssertEqual(
            json.propertyPaths.sorted(by: pathSort),
            [
                ["a"],
                ["b"],
                ["c"],
                ["c", "c1"],
                ["c", "c2"],
                ["c", "c2", "c21"],
                ["d"]
            ]
        )
    }
}

func pathSort(a: [String], b: [String]) -> Bool {
    return a.joined(separator: ",") < b.joined(separator: ",")
}
