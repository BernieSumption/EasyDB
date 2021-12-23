import XCTest

@testable import SwiftDB

class ValuesTests: XCTestCase {

    func testCounter2Values1Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        let next = { counter.next() as! Int }

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(counter.hasFinished, false)
        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

    func testCounter2Values0Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        XCTAssertEqual(counter.hasFinished, false)
        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

    func testCounter2Values2Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        let next = { counter.next() as! Int }

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)

        XCTAssertEqual(counter.hasFinished, false)
        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

    func testCounter2Values3Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        let next = { counter.next() as! Int }

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 1)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, false)

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

    func testCounter2Values4Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        let next = { counter.next() as! Int }

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, false)

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 2)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

    func testCounter2Values5Items() throws {
        let counter = ValueCycler(AnyValues(ArrayOfValues([1, 2])))
        let next = { counter.next() as! Int }

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 1)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, false)

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 2)
        XCTAssertEqual(next(), 1)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, false)

        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 1)
        XCTAssertEqual(next(), 2)

        counter.nextRow()
        XCTAssertEqual(counter.hasFinished, true)
    }

}
