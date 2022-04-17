import XCTest
import EasyDB

class DatabaseTests: EasyDBTestCase {

    func testExecute() throws {
        try db.execute("CREATE TABLE foo (a, b)")
        try db.execute("INSERT INTO foo (a, b) VALUES ('a', 'b'), ('c', 'd'), ('e', 'f')")
        let aNotEqualTo = "a"
        let result = try db.execute([[String]].self, "SELECT * FROM foo WHERE a != \(aNotEqualTo)")
        XCTAssertEqual(result, [["c", "d"], ["e", "f"]])
    }

    func testTransaction() throws {
        let database = EasyDB(.memory)
        struct Account: Codable, Identifiable {
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
}
