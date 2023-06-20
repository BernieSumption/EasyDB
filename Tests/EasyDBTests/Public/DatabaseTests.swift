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

    func testTransaction() throws {
        let database = db!
        struct Account: Record {
            var id: Int
            var balance: Int
        }
        try database.collection(Account.self).insert([
            Account(id: 1, balance: 100),
            Account(id: 2, balance: 0)
        ])
        // docs:start:database-transaction
        let accounts = try database.collection(Account.self)
        try database.transaction {
            guard var account1 = try accounts.filter(id: 1).fetchOne(),
                  var account2 = try accounts.filter(id: 2).fetchOne() else {
                throw MyError("Could not load accounts")
            }
            // move 10p from account 1 to account 2 without allowing the balance to go negative
            let amountToMove = max(account1.balance, 10)
            account1.balance -= amountToMove
            account2.balance += amountToMove
            try accounts.save(account1)
            try accounts.save(account2)
        }
        // docs:end
    }

    // TODO: remove this demo and use in real transaction tests
    func testSimultaneousTransactions() async throws {

        let waiter1 = Waiter()
        Task {
            print("in task: before await")
            await waiter1.wait()
            print("in task: after await")
        }
        print("before resume")
        waiter1.notify()
        print("after resume")

        await waiter1.wait()
    }
}

class Waiter {

    private var lock = true

    func notify() {
        assert(lock)
        lock = false
    }

    func wait() async {
        while lock {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}
