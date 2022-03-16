# SwiftDB

Swift developers already have some well established and reliable options for storing data in SQLite databases, such as [GRDB](https://github.com/groue/GRDB.swift) and [SQLite.swift](https://github.com/stephencelis/SQLite.swift). Why create another?

Simple: SwiftDB does not compete with GRDB. SwiftDB competes with `UserDefaults.set(_:forKey)`.

SwiftDB is designed to provide the best developer experience possible when storing large amounts of non-relational or document-oriented data. Just like storing `Codable` objects in `UserDefaults`, it requires zero configuration - including not requiring you to define a database schema. Unlike `UserDefaults` it has excellent performance with large data sets and a type-safe querying API based on key paths:

```
struct Book: Codable, Identifiable {
    var id = UUID()
    var name: String
    var author: String
    var price: Int // in pence
}
let db = SwiftDB()
let collection = db.collection(Book.self)
  // ^^ CREATE TABLE Book (id, name, author, price)

collection.insert([
    Book(name: "Catch-22", author: "Joseph Heller", price: 1050),
    Book(name: "Snow Crash", author: "Neal Stephenson", price: 1250),
    Book(name: "Nineteen Eighty-Four", author: "George Orwell", price: 799),
    Book(name: "A Pattern Language", author: "Christopher Alexander et al.", price: 2250)
])
  // ^^ INSERT INTO Book (name, author, price) VALUES (?, ?, ?) # executed 4 times in a transaction
  //    Inserts of many instances are batched into fewer queries for performance

let cheapBooks = collection.select().where(\.price, lessThan: 1000).fetchMany()
  // ^^ SELECT * FROM Book WHERE price > 1000
```

### Design goals

#### The best developer experience for simple storing and querying data

* Use the latest Swift APIs - Codable, KeyPath and string interpolations - to improve the developer experience
* Configurable (to an extent) but zero configuration required. No need to create a schema or even specify a database file name.

#### Embrace the schemaless document store mindset

TODO fill this one in. Maybe a bit of history about the RDBMS mindset vs document stores

#### When not to use SwiftDB

If your application needs to store data with complex relationships between objects and data invariants then you should: design a database schema making full use of SQLite's capability for enforcing constraints and referential integrity; use migrations to update the schema in a way that maintains these constraints; and think carefully about transactions and multithreading in your application. Under these circumstances I'd recommend using GRDB which is optimised for this kind of use case.

## API Comparison

TODO: compare API for GRDB, SQLite.swift and SwiftDB. Also compare performance on querying and insert.
