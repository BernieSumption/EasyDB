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
        
        let s = try c.prepare(sql: """
            SELECT
            :i AS i,
            :ioy AS ioy,
            :ion AS ion,
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
        
        try StatementEncoder().encode(KitchenSinkEntity.standard, into: s)
        
        let _ = try s.step()
        
        XCTAssertEqual(try s.readInt(column: "i"), 1)
        XCTAssertEqual(try s.readNull(column: "ioy"), false)
        XCTAssertEqual(try s.readInt(column: "ioy"), 1)
        XCTAssertEqual(try s.readNull(column: "ion"), true)
        XCTAssertEqual(try s.readInt(column: "i8"), 2)
        XCTAssertEqual(try s.readInt(column: "i16"), 3)
        XCTAssertEqual(try s.readInt(column: "i32"), 4)
        XCTAssertEqual(try s.readInt(column: "i64"), 5)
        XCTAssertEqual(try s.readInt(column: "ui"), 6)
        XCTAssertEqual(try s.readInt(column: "ui8"), 7)
        XCTAssertEqual(try s.readInt(column: "ui16"), 8)
        XCTAssertEqual(try s.readInt(column: "ui32"), 9)
        XCTAssertEqual(try s.readInt(column: "ui64"), 10)
        XCTAssertEqual(try s.readDouble(column: "f"), 11.5)
        XCTAssertEqual(try s.readDouble(column: "f16"), 12.5)
        XCTAssertEqual(try s.readDouble(column: "f32"), 13.5)
        XCTAssertEqual(try s.readDouble(column: "f64"), 14.5)
        XCTAssertEqual(try s.readDouble(column: "d"), 15.5)
        XCTAssertEqual(try s.readText(column: "s"), "16")
        XCTAssertEqual(try s.readBlob(column: "data"), Data([255, 6, 0, 179]))
        XCTAssertEqual(try s.readText(column: "date"), "2001-01-01T00:00:20Z")
        XCTAssertEqual(try s.readText(column: "sub"), #"{"a":21,"d":"2001-01-01T00:00:20Z"}"#)
    }
    
    func testEncodeDictionary() throws {
        let s = try c.prepare(sql: """
            SELECT
            :ioy AS ioy,
            :ion AS ion
        """)
        
        let value: [String: Int?] = ["ioy": 1, "ion": nil]
        try StatementEncoder().encode(value, into: s)
        
        let _ = try s.step()
        
        XCTAssertEqual(try s.readNull(column: "ioy"), false)
        XCTAssertEqual(try s.readInt(column: "ioy"), 1)
        XCTAssertEqual(try s.readNull(column: "ion"), true)
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


struct KitchenSinkEntity: Codable, Equatable {
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
    
    static let standard = KitchenSinkEntity(
        i: 1, ioy: 1, ion: nil, i8: 2, i16: 3, i32: 4, i64: 5, ui: 6, ui8: 7, ui16: 8, ui32: 9, ui64: 10,
        f: 11.5, f16: 12.5, f32: 13.5, f64: 14.5, d: 15.5, s: "16", data: Data([255, 6, 0, 179]),
        date: Date(timeIntervalSinceReferenceDate: 20),
        sub: .init(d: Date(timeIntervalSinceReferenceDate: 20), a: 21))
}
