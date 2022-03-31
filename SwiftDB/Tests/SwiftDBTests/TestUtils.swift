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

struct Row: Codable, Equatable, CustomStringConvertible {
    var value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    
    var description: String {
        return "Row(\(value))"
    }
}

struct RowT<T: Codable & Equatable>: Codable, Equatable, CustomStringConvertible, CustomTableName {
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    var description: String {
        return "RowT<\(T.self)>(\(value))"
    }
    
    static var tableName: String { "RowT" }
}

struct RowWithId: Codable, Equatable, Identifiable, CustomStringConvertible {
    let id: UUID
    
    init(_ id: UUID = UUID()) {
        self.id = id
    }
    
    var description: String {
        return "RowWithId(\(id))"
    }
}

struct RowWithString: Codable, Equatable, CustomStringConvertible {
    let string: String
    
    init(_ string: String) {
        self.string = string
    }
    
    var description: String {
        return "RowWithString(\(string))"
    }
}

class SwiftDBTestCase: XCTestCase {
    var db: Database!
    
    override func setUpWithError() throws {
        db = Database(path: ":memory:")
    }
    
    func populateCollection<T: Codable>(_ data: [T]) throws -> Collection<T> {
        let c = try db.collection(T.self)
        try db.execute("DELETE FROM \(name: c.tableName)")
        try c.insert(data)
        return c
    }
    
    func populateCollectionOfRowT<T: Codable>(_ data: [T]) throws -> Collection<RowT<T>> {
        let c = try db.collection(RowT<T>.self)
        try db.execute("DELETE FROM RowT")
        try c.insert(data.map(RowT<T>.init))
        return c
    }
    
    func assertFilter<T: Codable & Equatable>(
        _ data: [T],
        _ filter: (Collection<RowT<T>>) throws -> QueryBuilder<RowT<T>>,
        _ expected: [T]
    ) throws {
        let c = try populateCollectionOfRowT(data)
        XCTAssertEqual(
            try filter(c).fetchMany().map(\.value),
            expected)
    }
    
    func assertModification<T: Codable & Equatable>(
        _ data: [T],
        _ callback: (Collection<RowT<T>>) throws -> Void,
        _ expectedDataAfterCallback: [T]
    ) throws {
        let c = try populateCollectionOfRowT(data)
        try callback(c)
        XCTAssertEqual(
            try c.all().fetchMany().map(\.value),
            expectedDataAfterCallback)
    }
    
    func assertErrorMessage(_ expression: @autoclosure () throws -> Any, _ message: String) {
        XCTAssertThrowsError(try expression()) { error in
            XCTAssertEqual("\(error)", message)
        }
    }
    
    func assertErrorMessage(_ expression: @autoclosure () throws -> Any, contains: String) {
        XCTAssertThrowsError(try expression()) { error in
            let message = "\(error)"
            assertString(message, contains: contains)
        }
    }
    
    func assertString(_ string: String, contains: String) {
        XCTAssertTrue(string.contains(contains), "\"\(string)\" does not contain \"\(contains)\"")
    }
}
