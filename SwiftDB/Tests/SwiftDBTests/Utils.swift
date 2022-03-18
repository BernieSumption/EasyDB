import Foundation
import XCTest
import SwiftDB

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

struct RowWithValue: Codable, Equatable {
    var value: Int
    
    init(_ value: Int) {
        self.value = value
    }
}

struct RowWithId: Codable, Equatable, Identifiable {
    let id: UUID
    
    init(_ id: UUID = UUID()) {
        self.id = id
    }
}

class SwiftDBTestCase: XCTestCase {
    var db: Database!
    
    override func setUpWithError() throws {
        db = Database(path: ":memory:")
    }
    
    func assertThrowsConnectionError(_ expression: @autoclosure () throws -> Any, _ message: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertEqual((error as! ConnectionError).message, message)
        }
    }
    
    func assertThrowsConnectionError(_ expression: @autoclosure () throws -> Any, contains messagePart: String) {
        XCTAssertThrowsError(try expression()) { error in
            let message = (error as! ConnectionError).message!
            XCTAssertTrue(message.contains(messagePart), "\"\(message)\" does not contain \"\(messagePart)\"")
        }
    }
    
    func assertThrowsError(_ expression: @autoclosure () throws -> Any, _ message: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertEqual("\(error)", message)
        }
    }
    
    func assertThrowsError(_ expression: @autoclosure () throws -> Any, contains: String) {
        XCTAssertThrowsError(try expression()) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains(contains), "\"\(message)\" does not contain \"\(contains)\"")
        }
    }
}
