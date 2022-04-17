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

Before adopting EasyDB, consider some [reasons not to use EasyDB]. 

### System requirements
    
EasyDB requires Swift 5.5+ and runs on: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+.

It would be relatively easy to extend support back a few versions, PRs welcome, see [this issue](https://github.com/BernieSumption/EasyDB/issues/1).

### Design goals

#### The best developer experience for simple storing and querying data

* Use the latest Swift APIs - Codable, KeyPath and string interpolations - to improve the developer experience
* Configurable (to an extent) but zero configuration required. No need to create a schema or even specify a database file name.

#### Embrace the schemaless document store mindset

TODO fill this one in. Maybe a bit of history about the RDBMS mindset vs document stores

#### When not to use EasyDB

If your application needs to store data with complex relationships between objects and data invariants then you should: design a database schema making full use of SQLite's capability for enforcing constraints and referential integrity; use migrations to update the schema in a way that maintains these constraints; and think carefully about transactions and multithreading in your application. Under these circumstances I'd recommend using GRDB which is optimised for this kind of use case.

## API Comparison

TODO: compare API for GRDB, SQLite.swift and EasyDB. Also compare performance on querying and insert.

## Reasons not to use EasyDB

EasyDB has good test coverage and a great developer experience. Even in its first release, EasyDB is the best iOS database for my own needs. But your needs may be different.

- **You want type-safety across the full SQL API.** EasyDB does not completely hide you from SQL. Its philosophy is to provide a type-safe API for 90% of use cases and provide access to raw SQL so that you still have the full power of SQLite at your disposal. Personally I think that SQL is fine and your tests should catch any SQL syntax errors. If you disagree, use SQLite.swift
- **You want an explicit schema, constraints and migrations.** EasyDB follows the schemaless document store philosophy. Being based on SQLite is does in fact have a schema under the have a The application is responsible for enforcing data consistency, and the database operates as a high-performance but "dumb" data store. Referential integrity is achieved by storing nested arrays and objects in your records. If you prefer the relational database philosophy where you model complex data with multiple joined tables and expect the database to enforce referential integrity, use GRDB.
- You want to use advanced SQLite features. EasyDB does not support all features of SQLite, such as custom extensions (e.g. for full-text search), or data change notification callbacks.
- (Temporary) you want read and write in multiple threads (Link to [Concurrency and transactions]
