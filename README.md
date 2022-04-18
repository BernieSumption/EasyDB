# EasyDB

EasyDB is an application database for iOS and other Apple platforms. It wraps SQLite to provide an easy to use, high-performance, document-oriented database.

The goal of EasyDB is to provide the best developer experience with zero configuration, and taking advantage of modern Swift features. Compared to the (many) other SQLite wrappers, EasyDB the only one that provides a type-safe query API with no boilerplate code or configuration beyond defining your record type:

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

### The application is responsible for consistency

EasyDB encourages you to validate data consistency using Swift. For example, instead of defining a `NOT NULL` constraint on a column, define the property on the record type as non-optional. Instead of defining a `CHECK` constraint to ensure that a number is always positive, declare it as a `Uint` or write more complex validation code in Swift.

Referential integrity is a special case because the database is often better placed to validate referential integrity than the application. Referential integrity constraints are [on the roadmap](https://github.com/BernieSumption/EasyDB/issues/3), PRs are welcome.  

## Defining collections

Record types are `Codable` structs:

<!---defining-collections--->
```swift
struct MyRecord: Codable, Identifiable {
    var id = UUID()
    var name: String
}
```

Under the hood, EasyDB is using `Codable` to get a list of the properties of this struct and generate a table with `id` and `name` columns. 

Most record types should just work but some - especially any that have enums as properties - require a little extra code. See [Constraints on record types](#constraints-on-record-types).  

### Primary keys

To add a primary key, confirm your record type to `Identifiable`. A unique index will automatically be added.

We recommend `UUID` for IDs. Auto-incrementing integer IDs are not supported as they do not play nicely with Swift's type system.

## Constraints on record types

You can probably ignore this section - most Codable types will just work, including all the data types that you'd typically want to store in a database (strings, numbers, booleans, arrays, structs, dictionaries etc). However, if you get an error thrown while creating a querying collection, it may be because of an unsupported type.

There are two constraints on record types:

1. Your record type should use the compiler-synthesised `Codable` implementation: do not implement your own `init(from:)` or `encode(to:)` functions (it is fine however for your record types to use other types that have their own `Codable` implementations).
2. The primitive data types used by your record type must implement `SampleValueSource` or be decodable from the strings `"0"` or `"1"`, or the numbers `0` or `1`, or the booleans `false` or `true`. Most enums will not meet this requirement.

The second requirement may seem a bit odd. First we'll show how to conform to `SampleValueSource`, then we'll explain why this is necessary.

### Adding support for enums and other unsupported value types

Here's an example of an unsupported `Codable` type. The enum `Direction` encodes as a string, but `"0"` is not a valid direction:

<!---invalid-record-type--->
```swift
struct Record: Codable {
    var direction: Direction
}
// "0" is not a valid value for this enum
enum Direction: String, Codable {
    case up, down, left, right
}
XCTAssertThrowsError(
    // message: Error thrown from Direction.init(from:) ... Cannot initialize
    //          Direction from invalid String value 0
    try db.collection(Record.self)
)
```

The fix is as follows:

<!---fix-invalid-record-type--->
```swift
extension Direction: SampleValueSource {
    // return a `SampleValues` containing any two different instances
    static let sampleValues = SampleValues(Direction.up, Direction.down)
}
```

### Why is `SampleValueSource` necessary?

Understanding this requires some explanation of how EasyDB works under the hood.

One of the things that make EasyDB easy is that you can query using key paths, e.g. `filter(\.value, lessThan: 10)`. The algorithm that maps key paths to column names to enable this feature requires that EasyDB be able to create instances of your record types and of any other type used by the record type.

It does using `Codable` - it calls `YourRecordType.init(from: Decoder)`, passing a special Decoder instance that records how it is used. Your record type will ask the decoder for some data in the format that it expects. For example, if `YourRecordType` contains a property `var value: Int32` then `init(from: Decoder)` is going to ask the decoder for an `Int32` called `value` - specifically it will call `decoder.decode(Int32.self, forKey: "value")`. This is how EasyDB figures out the structure of Codable types. The decoder will respond by giving it a value of the kind requested: `"0"` or `"1"` for strings, `0` or `1` for numbers, `false` or `true` for booleans.

In the case of `Direction` in the example above, `"0"` was not a valid direction.

EasyDB extends a few common built-in types (`Date`, `Data`, `UUID` and `URL`) with conformance

This is fine for types that can be instantiated with one of these values. But some types that represent themselves as strings have requirements on the format of the string that they are instantiated with. Take `UUID` for example. It requires a UUID-formatted string. Trying to create a UUID with the string `"0"` will throw an error.

Because `UUID` is a commonly used type, EasyDB extends it with `SampleValueSource` conformance.

But if you use another type that encodes itself to a string but for which `"0"` or `"1"` are not valid representations, you will need to add `SampleValueSource` conformance yourself.

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
