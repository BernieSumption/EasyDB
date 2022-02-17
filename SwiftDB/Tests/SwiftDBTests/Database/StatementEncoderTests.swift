import XCTest
@testable import SwiftDB

class StatementEncoderTests: XCTestCase {
    
    let c: Connection! = try? Connection(path: ":memory:")
    
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
        
        try StatementEncoder.encode(KitchenSinkEntity.standard, into: s)
        
        let _ = try s.step()
        
        XCTAssertEqual(try s.read(column: "i"), .int(1))
        XCTAssertEqual(try s.readNull(column: "ioy"), false)
        XCTAssertEqual(try s.read(column: "ioy"), .int(1))
        XCTAssertEqual(try s.readNull(column: "ion"), true)
        XCTAssertEqual(try s.read(column: "i8"), .int(2))
        XCTAssertEqual(try s.read(column: "i16"), .int(3))
        XCTAssertEqual(try s.read(column: "i32"), .int(4))
        XCTAssertEqual(try s.read(column: "i64"), .int(5))
        XCTAssertEqual(try s.read(column: "ui"), .int(6))
        XCTAssertEqual(try s.read(column: "ui8"), .int(7))
        XCTAssertEqual(try s.read(column: "ui16"), .int(8))
        XCTAssertEqual(try s.read(column: "ui32"), .int(9))
        XCTAssertEqual(try s.read(column: "ui64"), .int(10))
        XCTAssertEqual(try s.read(column: "f"), .double(11.5))
        XCTAssertEqual(try s.read(column: "f16"), .double(12.5))
        XCTAssertEqual(try s.read(column: "f32"), .double(13.5))
        XCTAssertEqual(try s.read(column: "f64"), .double(14.5))
        XCTAssertEqual(try s.read(column: "d"), .double(15.5))
        XCTAssertEqual(try s.read(column: "s"), .text("16"))
        XCTAssertEqual(try s.read(column: "data"), .blob(Data([255, 6, 0, 179])))
        XCTAssertEqual(try s.read(column: "date"), .text("2001-01-01T00:00:20Z"))
        XCTAssertEqual(try s.read(column: "sub"), .text(#"{"a":21,"d":"2001-01-01T00:00:20Z"}"#))
    }
    
    func testEncodeDictionary() throws {
        let s = try c.prepare(sql: """
            SELECT
            :ioy AS ioy,
            :ion AS ion
        """)
        
        let value: [String: Int?] = ["ioy": 1, "ion": nil]
        try StatementEncoder.encode(value, into: s)
        
        let _ = try s.step()
        
        XCTAssertEqual(try s.readNull(column: "ioy"), false)
        XCTAssertEqual(try s.read(column: "ioy"), .int(1))
        XCTAssertEqual(try s.readNull(column: "ion"), true)
    }
    
    func testEncodeCodableArray() throws {
        let s = try c.prepare(sql: "SELECT ?, ?, ?")
        
        XCTAssertThrowsError(try StatementEncoder.encode([1, 2, 3], into: s)) { error in
            XCTAssertTrue(String(describing: error).contains("providing arrays of parameter values"))
        }
    }
    
    func testEncodeCodableScalars() throws {
        let s = try c.prepare(sql: "SELECT ?")
        
        XCTAssertThrowsError(try StatementEncoder.encode(1, into: s)) { error in
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
