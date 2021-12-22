import XCTest
@testable import SwiftDB

class JSONTests: XCTestCase {
    
    func testParseNumber() throws {
        XCTAssertEqual(
            try JSON(from: "1"),
            JSON.number(1)
        )
    }
    
    func testParseBoolean() throws {
        XCTAssertEqual(
            try JSON(from: "true"),
            JSON.boolean(true)
        )
    }
    
    func testParseNull() throws {
        XCTAssertEqual(
            try JSON(from: "null"),
            JSON.null
        )
    }
    
    func testParseKitchenSink() throws {
        XCTAssertEqual(
            try JSON(from: KitchenSink()),
            .object([
                "bool": .boolean(true),
                "float": .number(2.5),
                "int": .number(5.0),
                "string": .string("wotcha"),
                "object": .object([
                    "i": .number(8),
                    "aa": .array([.number(1)])
                ]),
                "arrayObjects": .array([
                    .object([
                        "i": .number(8),
                        "aa": .array([.number(1)])
                    ]),
                    .object([
                        "i": .number(8),
                        "aa": .array([.number(1)])
                    ])
                ]),
                "dict": .object([
                    "foo": .array([]),
                    "bar": .array([
                        .object([
                            "i": .number(8),
                            "aa": .array([.number(1)])
                        ])
                    ])
                ])
            ])
        )
    }
    
    struct KitchenSink: Encodable {
        let bool = true
        let float = 2.5
        let int = 5
        let string = "wotcha"
        let object = O()
        let arrayObjects = [O(), O()]
        let dict: [String: [O]] = ["foo": [], "bar": [O()]]
        
        struct O: Encodable {
            let i = 8
            let aa = [1]
        }
    }

}
