import XCTest
@testable import SwiftDB

class StatementDecoderTests: XCTestCase {
    
    let c: Connection! = try? Connection(path: ":memory:")
    
    func testSelectAs<T: Decodable & Equatable>(_ sql: String, _ type: T.Type, _ expected: T) throws {
        let s = try c.prepare(sql: sql)
        XCTAssertEqual(try StatementDecoder().decode(type, from: s), expected)
    }

    func testDecodeSingleIntegers() throws {
        
        func testInteger<T: Decodable & Equatable & FixedWidthInteger>(_ type: T.Type) throws {
            try testSelectAs("SELECT 1", T.self, 1)
            // encoders are supposed to wrap integers to Int64 since sqlite can't store UInt64 natively
            let max: T = T.max > Int64.max ? T(Int64(truncatingIfNeeded: T.max)) : T.max
            try testSelectAs("SELECT \(max.description)", type, max)
            try testSelectAs("SELECT \(T.min.description)", type.self, T.min)
        }
        
        try testInteger(Int.self)
        try testInteger(Int8.self)
        try testInteger(Int16.self)
        try testInteger(Int32.self)
        try testInteger(Int64.self)
        try testInteger(UInt8.self)
        try testInteger(UInt16.self)
        try testInteger(UInt32.self)
    }
    
    func testDecodeSingleFloats() throws {
        try testSelectAs("SELECT 1", Float.self, 1)
        try testSelectAs("SELECT -1000.123", Float.self, -1000.123)
        try testSelectAs("SELECT 1", Float32.self, 1)
        try testSelectAs("SELECT -1000.123", Float32.self, -1000.123)
        try testSelectAs("SELECT 1", Float64.self, 1)
        try testSelectAs("SELECT -1000.123", Float64.self, -1000.123)
        try testSelectAs("SELECT 1", Double.self, 1)
        try testSelectAs("SELECT -1000.123", Double.self, -1000.123)
        try testSelectAs("SELECT 1", Float16.self, 1)
        try testSelectAs("SELECT -1000.123", Float16.self, -1000.123)
    }
    
    func testDecodeSingleString() throws {
        try testSelectAs("SELECT ''", String.self, "")
        try testSelectAs("SELECT 'Unicode 统一码 😘'", String.self, "Unicode 统一码 😘")
    }
    
    func testDecodeSingleCodable() throws {
        try testSelectAs(
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
        try testSelectAs("SELECT x''", Data.self, Data())
        try testSelectAs("SELECT x'FF0600B3'", Data.self, Data([255, 6, 0, 179]))
    }
    
    func testDecodeSingleDate() throws {
        try testSelectAs("SELECT '2001-01-01T00:00:20Z'", Date.self, Date(timeIntervalSinceReferenceDate: 20))
    }
    
    func testDecodeSingleOptionals() throws {
        try testSelectAs("SELECT NULL", Int?.self, nil)
        try testSelectAs("SELECT 4", Int?.self, 4)
        try testSelectAs("SELECT NULL", MySingleCodable?.self, nil)
        try testSelectAs(
            #"SELECT '{"a": 2, "b": "foo", "data": "ERIT"}'"#,
            MySingleCodable?.self,
            MySingleCodable(a: 2, b: "foo", data: Data([17, 18, 19]))
        )
    }
    
    func testDecodeCodable() throws {
        let value = MyCodable(
            i: 1, ioy: 1, ion: nil, i8: 2, i16: 3, i32: 4, i64: 5, ui: 6, ui8: 7, ui16: 8, ui32: 9, ui64: 10,
            f: 11.5, f16: 12.5, f32: 13.5, f64: 14.5, d: 15.5, s: "16", data: Data([255, 6, 0, 179]),
            date: Date(timeIntervalSinceReferenceDate: 20),
            sub: .init(d: Date(timeIntervalSinceReferenceDate: 20), a: 21))
        try testSelectAs(
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
            """
            , MyCodable.self, value)
    }
    
    struct MyCodable: Codable, Equatable {
        let i: Int
        let ioy: Int?
        let ion: Int?
        let i8: Int8
        let i16: Int16
        let i32: Int32
        let i64: Int64
        let ui: UInt
        let ui8: UInt8
        let ui16: UInt16
        let ui32: UInt32
        let ui64: UInt64
        let f: Float
        let f16: Float16
        let f32: Float32
        let f64: Float64
        let d: Double
        let s: String
        let data: Data
        let date: Date
        let sub: Sub
        
        struct Sub: Codable, Equatable {
            let d: Date
            let a: Int
        }
    }
    
    func testDecodeDictionary() throws {
        try testSelectAs("SELECT 1 as foo, 2 as bar", [String: Int].self, ["foo": 1, "bar": 2])
        try testSelectAs("SELECT 1 as foo, '🎉' as bar", [String: String].self, ["foo": "1", "bar": "🎉"])
        try testSelectAs(
            #"SELECT '{"a":1}' as foo, '{"a":2}' as bar"#,
            [String: Sub].self,
            ["foo": Sub(a: 1), "bar": Sub(a: 2)])
        
        struct Sub: Codable, Equatable {
            let a: Int
        }
        
        try testSelectAs("SELECT 1 as foo, NULL as bar", [String: Int?].self, ["foo": 1, "bar": nil])
    }
    
    func testDecodeScalarArray() throws {
        try testSelectAs("SELECT 1 as foo", [Int].self, [1])
        try testSelectAs("SELECT 1 as foo UNION SELECT 2 as foo", [String].self, ["1", "2"])
    }
    
    func testDecodeStructArray() throws {
        try testSelectAs("SELECT 1 as i, 'foo' as s", [Row].self, [Row(i: 1, s: "foo")])
        try testSelectAs(
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
        try testSelectAs("SELECT 1 as foo, 2 as bar, 8 as baz", [[Int]].self, [[1, 2, 8]])
        try testSelectAs(
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
