import XCTest

@testable import EasyDB

// TODO: remove
class ConnectionFactoryTests: EasyDBTestCase {

    func testSemaphoreX() throws {
        let semaphore = DispatchSemaphore(value: 1)

        let c = try db.collection(RowWithString.self)

        self.measure {
            semaphore.wait()
            try? c.insert(RowWithString("X"))
            semaphore.signal()
        }
    }

    func testQueueX() throws {
        let queue = DispatchQueue(label: "myQueue")

        let c = try db.collection(RowWithString.self)

        self.measure {
            queue.sync {
                try? c.insert(RowWithString("X"))
            }
        }
    }

}
