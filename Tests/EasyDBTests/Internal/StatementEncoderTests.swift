import XCTest
@testable import EasyDB

class StatementEncoderTests: EasyDBTestCase {

    func testEncodeCodable() throws {

        let s = try getConnection().prepare(sql: """
            SELECT
            :id as id,
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
            :f32 AS f32,
            :f64 AS f64,
            :d AS d,
            :s AS s,
            :data AS data,
            :date AS date,
            :sub AS sub
        """)

        try StatementEncoder.encode(KitchenSinkRecord.standard, into: s)

        _ = try s.step()

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
        XCTAssertEqual(try s.read(column: "f32"), .double(13.5))
        XCTAssertEqual(try s.read(column: "f64"), .double(14.5))
        XCTAssertEqual(try s.read(column: "d"), .double(15.5))
        XCTAssertEqual(try s.read(column: "s"), .text("16"))
        XCTAssertEqual(try s.read(column: "data"), .blob(Data([255, 6, 0, 179])))
        XCTAssertEqual(try s.read(column: "date"), .text("2001-01-01T00:00:20Z"))
        XCTAssertEqual(try s.read(column: "sub"), .text(#"{"a":21,"d":"2001-01-01T00:00:20Z"}"#))
    }

    func testRegressionEncodeNulls() throws {
        let s = try getConnection().prepare(sql: """
            SELECT :a AS a
        """)

        try StatementEncoder.encode(A(a: 1), into: s)

        _ = try s.step()
        XCTAssertEqual(try s.read(column: "a"), .int(1))

        s.reset()

        // In a previous buggy version, nulls were not encoded because they came through to
        // to the encoder through `encodeIfPresent` which by default does nothing for
        // null values, which had the effect of leaving the previously bound value active
        try StatementEncoder.encode(A(a: nil), into: s)

        _ = try s.step()
        XCTAssertEqual(try s.read(column: "a"), .null)
    }

    struct A: Codable {
        let a: Int?
    }

    func testEncodeDictionary() throws {
        let s = try getConnection().prepare(sql: """
            SELECT
            :ioy AS ioy,
            :ion AS ion
        """)

        let value: [String: Int?] = ["ioy": 1, "ion": nil]
        try StatementEncoder.encode(value, into: s)

        _ = try s.step()

        XCTAssertEqual(try s.readNull(column: "ioy"), false)
        XCTAssertEqual(try s.read(column: "ioy"), .int(1))
        XCTAssertEqual(try s.readNull(column: "ion"), true)
    }

    func testEncodeCodableArray() throws {
        let s = try getConnection().prepare(sql: "SELECT ?, ?, ?")

        XCTAssertThrowsError(try StatementEncoder.encode([1, 2, 3], into: s)) { error in
            XCTAssertTrue(String(describing: error).contains("providing arrays of parameter values"))
        }
    }

    func testEncodeCodableScalars() throws {
        let s = try getConnection().prepare(sql: "SELECT ?")

        XCTAssertThrowsError(try StatementEncoder.encode(1, into: s)) { error in
            XCTAssertTrue(String(describing: error).contains("providing single parameter values"), String(describing: error))
        }
    }

    func testEncodeDate() throws {
        let s = try getConnection().prepare(sql: "SELECT :date as date")

        let date = Date(timeIntervalSinceReferenceDate: 20)
        try StatementEncoder.encode(["date": date], into: s)

        _ = try s.step()
        XCTAssertEqual(try s.read(column: "date"), .text("2001-01-01T00:00:20Z"))
    }
}
