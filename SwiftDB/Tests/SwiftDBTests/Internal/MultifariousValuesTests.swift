import XCTest

@testable import SwiftDB

class MultifariousValuesTests: XCTestCase {

    func test1Column() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, true)
    }

    func test2Columns() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, true)
    }

    func test3Columns() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, false)

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, true)
    }

    func test4Columns() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, false)

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, true)
    }

    func test5Columns() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, false)

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, false)

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(Int.self), 1)
        XCTAssertEqual(mv.hasFinished, false)
        mv.nextRow()
        XCTAssertEqual(mv.hasFinished, true)
    }

    func testMixedValuesColumn() throws {
        let mv = MultifariousValues()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(UInt8.self), 1)
        XCTAssertEqual(mv.next(Float32.self), 0)
        mv.nextRow()

        XCTAssertEqual(mv.next(Int.self), 0)
        XCTAssertEqual(mv.next(UInt8.self), 0)
        XCTAssertEqual(mv.next(Float32.self), 1)
    }

    func first2Values<T: Equatable>(_ type: T.Type) -> [T?] {
        let mv = MultifariousValues()
        return [mv.next(type), mv.next(type)]
    }

    func testBuiltInTypes() throws {
        XCTAssertEqual(first2Values(Bool.self), [false, true])
        XCTAssertEqual(first2Values(String.self), ["0", "1"])
        XCTAssertEqual(first2Values(Double.self), [0, 1])
        XCTAssertEqual(first2Values(Float.self), [0, 1])
        XCTAssertEqual(first2Values(Int.self), [0, 1])
        XCTAssertEqual(first2Values(Int8.self), [0, 1])
        XCTAssertEqual(first2Values(Int16.self), [0, 1])
        XCTAssertEqual(first2Values(Int32.self), [0, 1])
        XCTAssertEqual(first2Values(Int64.self), [0, 1])
        XCTAssertEqual(first2Values(UInt.self), [0, 1])
        XCTAssertEqual(first2Values(UInt8.self), [0, 1])
        XCTAssertEqual(first2Values(UInt16.self), [0, 1])
        XCTAssertEqual(first2Values(UInt32.self), [0, 1])
        XCTAssertEqual(first2Values(UInt64.self), [0, 1])
        XCTAssertEqual(first2Values(Decimal.self), [0, 1])
        XCTAssertEqual(first2Values(URL.self), [URL(string: "data:,0")!, URL(string: "data:,1")!])
        XCTAssertEqual(
            first2Values(UUID.self),
            [
                UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
            ])
        XCTAssertEqual(
            first2Values(Date.self),
            [
                Date(timeIntervalSince1970: 0),
                Date(timeIntervalSince1970: 1)
            ])
        XCTAssertEqual(
            first2Values(Data.self),
            [
                Data(repeating: 0, count: 1),
                Data(repeating: 1, count: 1)
            ])
    }

    func testCustomType() throws {
        XCTAssertEqual(first2Values(CustomType.self), [CustomType(v: 10), CustomType(v: -10)])
    }

    struct CustomType: SampleValueSource, Codable, Equatable {
        let v: Int

        static func provideSampleValues(_ receiver: SampleValueReceiver) {
            receiver.setSampleValues(CustomType(v: 10), CustomType(v: -10))
        }
    }
}
