# EasyDB

EasyDB is an application database for iOS and other Apple platforms. It wraps SQLite to provide an easy to use, high-performance, document-oriented database.

The goal of EasyDB is to provide the best developer experience with zero configuration. Compared to the (many) other SQLite wrappers, EasyDB the only one that provides a type-safe query API with no boilerplate code or configuration beyond defining your record type:

<!---headline-demo--->
```swift
// Record types are defined as Codable structs
struct Book: Codable, Identifiable {
    var id = UUID()
    @Unique var name: String
    var author: String
    var priceCents: Int
}
let database = EasyDB("my-database.sqlite")
let books = try database.collection(Book.self)
//  ^^ CREATE TABLE Book (id, name, author, price)
//     CREATE UNIQUE INDEX `book-unique-id` ON Book (`id`) # ids are automatically unique
//     CREATE UNIQUE INDEX `book-unique-name` ON Book (`name`)

try books.insert(Book(name: "Catch-22", author: "Joseph Heller", priceCents: 1050))
//  ^^ INSERT INTO Book (id, name, author, priceCents) VALUES (?, ?, ?, ?)

// fluent type-safe API for querying based on key paths
let cheapBooks = try books.all()
    .filter(\.priceCents, lessThan: 1000)
    .orderBy(\.author, .descending)
    .fetchMany()
//  ^^ SELECT * FROM Book WHERE `priceCents` < ? ORDER BY `author` DESC
```

Before adopting EasyDB, consider some [reasons not to use EasyDB](#reasons-not-to-use-easydb). 

### System requirements
    
EasyDB requires Swift 5.5+ and runs on: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+.

It would be relatively easy to extend support back a few versions, PRs welcome, see [this issue](https://github.com/BernieSumption/EasyDB/issues/1).

## The EasyDB philosophy

### A schemaless document store

Being based on SQLite there is a schema under the hood, but EasyDB manages this schema for you. New database columns are automatically added to the underlying table when you add them to your record type. 

### `Codable` record types

EasyDB relies heavily on [`Codable`](https://developer.apple.com/documentation/swift/codable) to move data to and from the database.

### The application is responsible for consistency

EasyDB encourages you to validate data consistency using Swift. For example, instead of defining a `NOT NULL` constraint on a column, define the property on the record type as non-optional. Instead of defining a `CHECK` constraint to ensure that a number is always positive, declare it as a `Uint` or write more complex validation code in Swift.

Referential integrity is a special case because the database is often better placed to validate referential integrity than the application. Referential integrity constraints are [on the roadmap](https://github.com/BernieSumption/EasyDB/issues/3), PRs are welcome.  

### Design goals

#### The best developer experience for simple storing and querying data

* Use the latest Swift APIs - Codable, KeyPath and string interpolations - to improve the developer experience
* Configurable (to an extent) but zero configuration required. No need to create a schema or even specify a database file name.

#### Embrace the schemaless document store mindset

TODO fill this one in. Maybe a bit of history about the RDBMS mindset vs document stores


## Concurrency and transactions

The EasyDB API is thread-safe provided that you **only create a single `EasyDB` instance for each database file**. You can use the database simultaneously from multiple threads. Statements are executed in a serial queue: even if you read and write from multiple threads, only one will execute at a time. This provides acceptable performance for most apps (Apple's own apps use Core Data which has the same restriction).

Bulk insert and save operations automatically run in a transaction - if one record fails to save e.g. due to failing a unique constraint, the transaction will be rolled back and no records will be saved.

If your application is multi-threaded and wants to read data then make conditional updates based on that data, this level of automatic transaction is not enough. For example, if you want to check an account balance and only transfer money between accounts if there is sufficient balance, you have to consider that another thread may have updated the balance between your reading and writing it, potentially leading to an incorrect balance. In this situation, use `database.transaction(block:)`. This executes a block of code inside a transaction, rolling back the transaction if the block throws an exception. The block is executed in the same serial queue as all other statements, ensuring that other threads can not modify the account concurrently.

<!---database-transaction--->
```swift
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
```

Bear in mind that no other reads or writes can take place while the block is executing, so avoid time-consuming processing in the block.

Genuine multiple reader single writer concurrency using SQLite's WAL mode is [on the roadmap](https://github.com/BernieSumption/EasyDB/issues/2) and PRs are welcome.

## Reasons not to use EasyDB

Even in its first release, EasyDB is the best iOS database for _my_ needs. But your needs may be different. If you need any of these features _now_ then use a different database. Bear in mind that it's not hard to migrate from EasyDB to any other SQLite-based database as they all use the same data file format, so if you don't require these features now but think you might in the future, you can use EasyDB knowing that you're not locked in.

**You want type-safety across the full SQL API.** EasyDB does not completely hide you from SQL. Its philosophy is to provide a type-safe API for 90% of use cases and provide access to raw SQL so that you still have the full power of SQLite at your disposal. Personally I think that SQL is fine and your tests should catch any SQL syntax errors. If you disagree, use SQLite.swift

**You want an explicit schema, constraints and migrations.** EasyDB follows the [schemaless document database philosophy](#the-easydb-philosophy). The application is responsible for enforcing data consistency, and the database operates as a high-performance but "dumb" data store. You write less code because there is no need to define a schema or write migrations to evolve your schema between application versions. But fans of schema-driven databases regard the schema definition as a kind of double-entry bookkeeping that helps you write reliable applications. If you want to define an explicit schema, use GRDB.

**You want to use advanced SQLite features.** EasyDB does not currently support the following features. There's no reason why it can't, it just doesn't yet:
  - _WAL mode:_ SQLite supports single-writer-multiple-reader concurrency via [WAL mode](https://www.sqlite.org/wal.html). Adding this to EasyDB is a high priority but for now EasyDB offers [thread safety but no concurrency](#concurrency-and-transactions). In fairness this is already better than Core Data which has neither concurrency nor thread safety.
  - _Change notification:_ SQLite can [notify you](https://sqlite.org/c3ref/update_hook.html) when your database is updated by another process. It is easy for your app to notify itself when it writes to the database, but if other processes may write to the same database file and you want to respond to those changes immediately, use GRDB.
  - _full text search:_ EasyDB does not support full-text search with the [FTS4 module](https://www.sqlite.org/fts3.html). 
  - _custom builds:_ EasyDB uses the system-provided SQLite and you can not provide your own build, e.g. to use extensions like [SQLCipher](https://www.zetetic.net/sqlcipher/) or) [SpatiaLite](https://www.gaia-gis.it/fossil/libspatialite/index). 
