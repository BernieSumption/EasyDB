import XCTest
@testable import SwiftDB

class StatementEncoderTests: XCTestCase {
    
    let c: Connection! = try? Connection(path: ":memory:")
    
    func testTmp() throws {
        let _ = try c.prepare(sql: "CREATE TABLE foo (a)").step()
        let _ = try c.prepare(sql: "INSERT INTO foo (a) VALUES (1), (2), (3), (4)").step()
        let s = try c.prepare(sql: "SELECT * FROM foo WHERE a > :foo")
        
        try StatementEncoder().encode(Args(foo: 2), into: s)
        
        XCTAssertEqual(try StatementDecoder().decode([Int].self, from: s), [3, 4])
        
        
        
        struct Args: Codable {
            let foo: Int
        }
    }
    
    func testEncodeCodable() throws {
        let value = MyCodable(
            i: 1, i8: 2, i16: 3, i32: 4, i64: 5, ui: 6, ui8: 7, ui16: 8, ui32: 9, ui64: 10,
            f: 11, f16: 12, f32: 13, f64: 14, d: 15, s: "16", data: Data([255, 6, 0, 179]),
            date: Date(timeIntervalSinceReferenceDate: 20),
            sub: .init(d: Date(timeIntervalSinceReferenceDate: 20), a: 21))
        
        let s = try c.prepare(sql: """
            SELECT
            :i AS i,
            :i8 AS i8,
            :i16 AS i16,
            :i32 AS i32,
            :i64 AS i64,
            :ui AS ui,
            :ui8 AS ui8,
            :ui16 AS ui16,
            :ui32 AS ui32,
            :ui64 AS ui64,
            :f AS f,
            :f16 AS f16,
            :f32 AS f32,
            :f64 AS f64,
            :d AS d,
            :s AS s,
            :data AS data,
            :date AS date,
            :sub AS sub
        """)
        
        try StatementEncoder().encode(value, into: s)
        
        let decoded = try StatementDecoder().decode(MyCodable.self, from: s)
        
        XCTAssertEqual(decoded, value)
    }
    
    struct MyCodable: Codable, Equatable {
        let i: Int
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
    
    func testEncodeCodableArray() throws {
        let s = try c.prepare(sql: "SELECT ?, ?, ?")
        
        XCTAssertThrowsError(try StatementEncoder().encode([1, 2, 3], into: s)) { error in
            XCTAssertTrue(String(describing: error).contains("providing arrays of parameter values"))
        }
    }
    
    func testEncodeCodableScalars() throws {
        let s = try c.prepare(sql: "SELECT ?, ?, ?")
        
        XCTAssertThrowsError(try StatementEncoder().encode(1, into: s)) { error in
            XCTAssertTrue(String(describing: error).contains("providing single parameter values"), String(describing: error))
        }
    }

}
