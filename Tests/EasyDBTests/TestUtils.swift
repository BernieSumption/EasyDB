import Foundation
import XCTest
@testable import EasyDB

struct KitchenSinkRecord: Record, Equatable {
    var id: String
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

    static let standard = KitchenSinkRecord(
        id: "id", i: 1, ioy: 1, ion: nil, i8: 2, i16: 3, i32: 4, i64: 5, ui: 6, ui8: 7, ui16: 8, ui32: 9, ui64: 10,
        f: 11.5, f32: 13.5, f64: 14.5, d: 15.5, s: "16", data: Data([255, 6, 0, 179]),
        date: Date(timeIntervalSinceReferenceDate: 20),
        sub: .init(d: Date(timeIntervalSinceReferenceDate: 20), a: 21))
}

struct Row: Record, Equatable, CustomStringConvertible {
    var id = UUID()
    var value: Int

    init(_ value: Int) {
        self.value = value
    }

    var description: String {
        return "Row(\(value))"
    }
}

struct RowT<T: Codable & Equatable>: Record, Equatable, CustomStringConvertible {
    var id = UUID()
    var value: T

    init(_ value: T) {
        self.value = value
    }

    var description: String {
        return "RowT<\(T.self)>(\(value))"
    }

    static var tableName: String { "RowT" }
}

struct RowWithId: Record, Equatable, CustomStringConvertible {
    let id: UUID

    init(_ id: UUID = UUID()) {
        self.id = id
    }

    var description: String {
        return "RowWithId(\(id))"
    }
}

struct RowWithString: Record, Equatable, CustomStringConvertible {
    var id = UUID()
    var string: String

    init(_ string: String) {
        self.string = string
    }

    var description: String {
        return "RowWithString(\(string))"
    }
}

let testFilePath = NSTemporaryDirectory() + "EasyDBTestCase.sqlite"

class EasyDBTestCase: XCTestCase {
    var db: EasyDB!

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: testFilePath) {
            try? FileManager.default.removeItem(atPath: testFilePath)
        }
        db = EasyDB(.path(testFilePath))
    }

    override func tearDownWithError() throws {
        db = nil
        XCTAssertEqual(liveEasyDBInstances, 0, "Memory leak detected: \(liveEasyDBInstances) live EasyDB instances remain")
        XCTAssertEqual(liveCollectionInstances, 0, "Memory leak detected: \(liveCollectionInstances) live Collection instances remain")
        if FileManager.default.fileExists(atPath: testFilePath) {
            try? FileManager.default.removeItem(atPath: testFilePath)
        }
    }

    func populateCollection<Row: Record>(_ data: [Row]) throws -> Collection<Row> {
        let c = try db.collection(Row.self)
        try c.all().delete()
        try c.insert(data)
        return c
    }

    func populateCollectionOfRowT<T: Codable>(_ data: [T]) throws -> Collection<RowT<T>> {
        let c = try db.collection(RowT<T>.self)
        try c.all().delete()
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

    /// Return the SQL for all indices in the database
    func dbIndices() throws -> [String] {
        return try db.execute([String].self, "SELECT sql FROM sqlite_schema WHERE type = 'index'")
    }

    func getConnection() throws -> Connection {
        try db.withConnection(write: true) { connection in
            return connection
        }
    }
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

struct MyError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
