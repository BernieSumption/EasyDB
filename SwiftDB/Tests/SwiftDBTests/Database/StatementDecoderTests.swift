import XCTest
@testable import SwiftDB

class StatementDecoderTests: XCTestCase {
    
    let c: Connection! = try? Connection(path: ":memory:")

    func testDecodeIntegers() throws {
        func testInteger<T: Decodable & Equatable & FixedWidthInteger>(_ type: T.Type) {
            testSelectAs("SELECT 1", T.self, 1)
            testSelectAs("SELECT \(T.max)", type, T.max)
            testSelectAs("SELECT \(T.min)", type.self, T.min)
        }
        
        testInteger(Int.self)
        testInteger(Int8.self)
        testInteger(Int16.self)
        testInteger(Int32.self)
        testInteger(Int64.self)
        testInteger(UInt8.self)
        testInteger(UInt16.self)
        testInteger(UInt32.self)
        
        testSelectError("SELECT 12345", Int8.self, "could not exactly represent 12345 as Int8")
    }
    
    func testDecodeConversionsToInteger() throws {
        testSelectAs("SELECT 1.0", Int.self, 1)
        
        testSelectError("SELECT 1.7", Int.self, "could not exactly represent 1.7 as Int")
        testSelectError("SELECT NULL", Int.self, "expected int got null")
        testSelectError("SELECT 'foo'", Int.self, "expected int got text")
        testSelectError("SELECT x'12'", Int.self, "expected int got blob")
    }
    
    func testDecodeDouble() throws {
        testSelectAs("SELECT 1.0", Float.self, 1)
        testSelectAs("SELECT -1000.123", Float.self, -1000.123)
        testSelectAs("SELECT 1.0", Float32.self, 1)
        testSelectAs("SELECT -1000.123", Float32.self, -1000.123)
        testSelectAs("SELECT 1.0", Float64.self, 1)
        testSelectAs("SELECT -1000.123", Float64.self, -1000.123)
        testSelectAs("SELECT 1.0", Double.self, 1)
        testSelectAs("SELECT -1000.123", Double.self, -1000.123)
        testSelectAs("SELECT 1.0", Float16.self, 1)
        testSelectAs("SELECT -1000.123", Float16.self, -1000.123)
    }
    
    func testDecodeConversionsToDouble() throws {
        testSelectAs("SELECT 1", Double.self, 1)
        
        testSelectError("SELECT NULL", Double.self, "expected double got null")
        testSelectError("SELECT 'foo'", Double.self, "expected double got text")
        testSelectError("SELECT x'12'", Double.self, "expected double got blob")
    }
    
    func testDecodeString() throws {
        testSelectAs("SELECT ''", String.self, "")
        testSelectAs("SELECT 'Unicode 统一码 😘'", String.self, "Unicode 统一码 😘")
    }
    
    func testDecodeConversionsToString() throws {
        testSelectAs("SELECT 1", String.self, "1")
        testSelectAs("SELECT 1.0", String.self, "1.0")
        
        testSelectError("SELECT NULL", String.self, "expected text got null")
        testSelectError("SELECT x'12'", String.self, "expected text got blob")
    }
    
    func testDecodeSingleCodable() throws {
        testSelectAs(
            #"SELECT '{"a": 2, "b": "foo", "data": "ERIT"}'"#,
            MySingleCodable.self,
            MySingleCodable(a: 2, b: "foo", data: Data([17, 18, 19]))
        )
    }
    
    /// A type that stores a single Decodable property in a single value container
    ///
    /// This is an odd thing to do over using a keyed container (as far as I know synthesised
    /// decodable implementations never do it) but the Decoder API allows it
    struct MySingleCodable: Codable, Equatable {
        let mc: MyCodable
        
        init(a: Int, b: String, data: Data) {
            self.mc = MyCodable(a: a, b: b, data: data)
        }
        
        init(from decoder: Decoder) throws {
            mc = try decoder.singleValueContainer().decode(MyCodable.self)
        }
        
        struct MyCodable: Codable & Equatable {
            let a: Int
            let b: String
            let data: Data
        }
    }
    
    func testDecodeSingleData() throws {
        testSelectAs("SELECT x''", Data.self, Data())
        testSelectAs("SELECT x'FF0600B3'", Data.self, Data([255, 6, 0, 179]))
    }
    
    func testDecodeSingleDate() throws {
        testSelectAs("SELECT '2001-01-01T00:00:20Z'", Date.self, Date(timeIntervalSinceReferenceDate: 20))
    }
    
    func testDecodeSingleOptionals() throws {
        testSelectAs("SELECT NULL", Int?.self, nil)
        testSelectAs("SELECT 4", Int?.self, 4)
        testSelectAs("SELECT NULL", MySingleCodable?.self, nil)
        testSelectAs(
            #"SELECT '{"a": 2, "b": "foo", "data": "ERIT"}'"#,
            MySingleCodable?.self,
            MySingleCodable(a: 2, b: "foo", data: Data([17, 18, 19])))
    }
    
    func testDecodeCodable() throws {
        testSelectAs(
            """
                SELECT
                1 AS i,
                1 AS ioy,
                NULL AS ion,
                2 AS i8,
                3 AS i16,
                4 AS i32,
                5 AS i64,
                6 AS ui,
                7 AS ui8,
                8 AS ui16,
                9 AS ui32,
                10 AS ui64,
                11.5 AS f,
                12.5 AS f16,
                13.5 AS f32,
                14.5 AS f64,
                15.5 AS d,
                "16" AS s,
                x'FF0600B3' AS data,
                "2001-01-01T00:00:20Z" AS date,
                '{"a":21,"d":"2001-01-01T00:00:20Z"}' AS sub
            """,
            KitchenSinkEntity.self,
            KitchenSinkEntity.standard)
    }
    
    func testDecodeDictionary() throws {
        testSelectAs("SELECT 1 as foo, 2 as bar", [String: Int].self, ["foo": 1, "bar": 2])
        testSelectAs("SELECT 'x' as foo, '🎉' as bar", [String: String].self, ["foo": "x", "bar": "🎉"])
        testSelectAs(
            #"SELECT '{"a":1}' as foo, '{"a":2}' as bar"#,
            [String: Sub].self,
            ["foo": Sub(a: 1), "bar": Sub(a: 2)])
        
        struct Sub: Codable, Equatable {
            let a: Int
        }
        
        testSelectAs("SELECT 1 as foo, NULL as bar", [String: Int?].self, ["foo": 1, "bar": nil])
    }
    
    func testDecodeScalarArray() throws {
        testSelectAs("SELECT 1 as foo", [Int].self, [1])
        testSelectAs("SELECT 1 as foo UNION SELECT 2 as foo", [String].self, ["1", "2"])
    }
    
    func testDecodeStructArray() throws {
        testSelectAs("SELECT 1 as i, 'foo' as s", [Row].self, [Row(i: 1, s: "foo")])
        testSelectAs(
            """
                SELECT 1 as i, 'foo' as s
                UNION
                SELECT 2 as i, 'bar' as s
            """,
            [Row].self,
            [
                Row(i: 1, s: "foo"),
                Row(i: 2, s: "bar")
            ]
        )
        
        struct Row: Codable, Equatable {
            let i: Int
            let s: String
        }
    }
    
    func testDecodeScalarArrays() throws {
        testSelectAs("SELECT 1 as foo, 2 as bar, 8 as baz", [[Int]].self, [[1, 2, 8]])
        testSelectAs(
            """
                SELECT 1 as foo, 2 as bar
                UNION
                SELECT 'snoz' as foo, 'plonk' as bar
            """,
            [[String]].self,
            [
                ["1", "2"],
                ["snoz", "plonk"]
            ]
        )
    }
}

extension StatementDecoderTests {
    
    func selectAs<T: Decodable & Equatable>(_ sql: String, _ type: T.Type) throws -> T {
        let s = try c.prepare(sql: sql)
        return try StatementDecoder.decode(type, from: s)
    }

    func testSelectAs<T: Decodable & Equatable>(_ sql: String, _ type: T.Type, _ expected: T) {
        XCTAssertEqual(try selectAs(sql, type), expected)
    }
    
    func testSelectError<T: Decodable & Equatable>(_ sql: String, _ type: T.Type, _ message: String) {
        XCTAssertThrowsError(try selectAs(sql, type)) { error in
            XCTAssertEqual(String(describing: error), message)
        }
    }
}
