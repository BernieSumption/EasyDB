# EasyDB

EasyDB is an application database for iOS and other Apple platforms. It wraps SQLite to provide an easy to use, high-performance, document-oriented database.

The goal of EasyDB is to provide the best developer experience with zero configuration. Compared to the (many) other SQLite wrappers, EasyDB the only one that provides a type-safe query API with no boilerplate code or configuration beyond defining.

<!---headline-demo--->
```swift
// Record types are defined as Codable Swift structs
struct Book: Codable, Identifiable {
    var id = UUID()
    @Unique var name: String
    var author: String
    var priceCents: Int
}
let books = try database.collection(Book.self)
//  ^^ CREATE TABLE Book (id, name, author, price)
//     CREATE UNIQUE INDEX `book-unique-id` ON Book (`id`) # ids are automatically unique
//     CREATE UNIQUE INDEX `book-unique-name` ON Book (`name`)

try books.insert(Book(name: "Catch-22", author: "Joseph Heller", priceCents: 1050))
//  ^^ INSERT INTO Book (name, author, price) VALUES (?, ?, ?)

// fluent type-safe API for querying based on key paths
let cheapBooks = try books.all()
    .filter(\.priceCents, lessThan: 1000)
    .orderBy(\.author, .descending)
    .fetchMany()
//  ^^ SELECT * FROM Book WHERE `price` < ? ORDER BY `author` DESC
```

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
