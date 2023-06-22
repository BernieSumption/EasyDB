import XCTest
import EasyDB
import class Combine.Future

class DatabaseTests: EasyDBTestCase {

    func testExecute() throws {
        try db.execute("CREATE TABLE foo (a, b)")
        try db.execute("INSERT INTO foo (a, b) VALUES ('a', 'b'), ('c', 'd'), ('e', 'f')")
        let aNotEqualTo = "a"
        let result = try db.execute([[String]].self, "SELECT * FROM foo WHERE a != \(aNotEqualTo)")
        XCTAssertEqual(result, [["c", "d"], ["e", "f"]])
    }

    func testTransactionCommit() throws {
        let c = try db.collection(Row.self)
        XCTAssertEqual(try c.all().fetchMany(), [])
        try db.write {
            try c.insert(Row(1))
        }
        XCTAssertEqual(try c.all().fetchMany().map(\.value), [1])
    }

    func testTransactionRollback() throws {
        let c = try db.collection(Row.self)
        XCTAssertEqual(try c.all().fetchMany(), [])
        XCTAssertThrowsError(
            try db.write {
                try c.insert(Row(1))
                throw EasyDBError.unexpected(message: "whoops!")
            }
        )
        XCTAssertEqual(try c.all().fetchMany(), [])
    }

    func testNestedTransactionRollback() throws {
        db.logSQL = .print
        let c = try db.collection(Row.self)
        XCTAssertEqual(try c.all().fetchMany(), [])
        try db.write {
            try c.insert(Row(1))
            try? db.write {
                try c.insert(Row(2))
                throw EasyDBError.unexpected(message: "whoops!")
            }
            try c.insert(Row(3))
        }
        XCTAssertEqual(try c.all().fetchMany().map(\.value), [1, 3])
    }

    func testSingleWriter() throws {
        // create task 1 and start a write
        let task1WriteStarted = DispatchSemaphore(value: 0)
        let task1AllowExit = DispatchSemaphore(value: 0)
        let task1Finished = DispatchSemaphore(value: 0)
        Task {
            try db.write {
                task1WriteStarted.signal()
                task1AllowExit.wait()
            }
            task1Finished.signal()
        }

        // wait for task 1's write to begin
        task1WriteStarted.wait()

        // create task 2 and attempt to start a concurrent write
        let task2WriteStarted = DispatchSemaphore(value: 0)
        let task2Finished = DispatchSemaphore(value: 0)
        Task {
            try db.write {
                _ = task2WriteStarted.signal()
            }
            task2Finished.signal()
        }

        // Expect a timeout as task 2 is blocked waiting for task 1 to finish writing
        XCTAssertEqual(
            task2WriteStarted.wait(timeout: .now().advanced(by: .milliseconds(20))),
            .timedOut)

        task1AllowExit.signal()

        // Expect a success as task 2 is now allowed to write
        XCTAssertEqual(
            task2WriteStarted.wait(timeout: .now().advanced(by: .milliseconds(100))),
            .success)

        task1Finished.wait()
        task2Finished.wait()
    }

    func testMultipleReaders() throws {
        // create task 1 and start a read
        let task1ReadStarted = DispatchSemaphore(value: 0)
        let task1AllowExit = DispatchSemaphore(value: 0)
        let task1Finished = DispatchSemaphore(value: 0)
        Task {
            try db.read {
                task1ReadStarted.signal()
                task1AllowExit.wait()
            }
            task1Finished.signal()
        }

        // wait for task 1's read to begin
        task1ReadStarted.wait()

        // create task 2 and start a concurrent read
        let task2ReadStarted = DispatchSemaphore(value: 0)
        let task2Finished = DispatchSemaphore(value: 0)
        Task {
            try db.read {
                _ = task2ReadStarted.signal()
            }
            task2Finished.signal()
        }

        // Expect a success as task 2 is allowed to read concurrently with task1
        XCTAssertEqual(
            task2ReadStarted.wait(timeout: .now().advanced(by: .milliseconds(20))),
            .success)

        task1AllowExit.signal()

        task1Finished.wait()
        task2Finished.wait()
    }

    func testErrorIfWriteInReadBlock() throws {
        let col = try db.collection(Row.self)
        assertErrorMessage(
            try db.read {
                try col.insert(Row(1))
            },
            contains: "attempt to write a readonly database")
    }

    func testErrorIfExecuteWritingSQLInReadBlock() throws {
        try db.execute("CREATE TABLE t (value)")

        try db.execute("INSERT INTO t (value) VALUES (1)")

        try db.write {
            try db.execute("INSERT INTO t (value) VALUES (2)")
        }

        assertErrorMessage(
            try db.read {
                try db.execute("INSERT INTO t (value) VALUES (3)")
            },
            contains: "attempt to write a readonly database")

        XCTAssertEqual(try db.execute([Int].self, "SELECT value from t"), [1, 2])
    }

    func testNoErrorIfExecuteReadonlySQLInReadBlock() throws {
        try db.execute("CREATE TABLE t (value)")

        try db.execute("INSERT INTO t (value) VALUES (1)")

        try db.read {
            XCTAssertEqual(try db.execute([Int].self, "SELECT value from t"), [1])
        }
    }
}

class Flag {
    var value: Bool

    init(_ value: Bool) {
        self.value = value
    }
}
