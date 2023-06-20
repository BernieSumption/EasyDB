# EasyDB

EasyDB is an application database for iOS and other Apple platforms designed for the best developer experience. Based on SQLite for performance and reliability, it provides:

- A fully automatic, type-safe API that covers most common use cases
- Safe access SQL for the less common use cases 
- Thread-safety: use the database concurrently from multiple threads/tasks
- Documented-oriented design philosophy: store arbitrary structured data in your records

## Introduction

Compared to the (many) other SQLite wrapper libraries in Swift, EasyDB is the only one that provides a type-safe query API with no boilerplate code or configuration beyond defining your record type:

<!---headline-demo--->
```swift
// Record types are defined as Codable structs
struct Book: Record {
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

EasyDB is inspired by schemaless databases like MongoDB that allow documents to contain arbitrary hierarchical structured data. Being based on SQLite there is a schema under the hood, but EasyDB manages this schema for you. New database columns are automatically added to the underlying table when you add them to your record type.

Before adopting EasyDB, consider some [reasons not to use EasyDB](#reasons-not-to-use-easydb).

### System requirements
    
EasyDB requires Swift 5.5+ and runs on: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+.

It would be relatively easy to extend support back a few versions, see [this issue](https://github.com/BernieSumption/EasyDB/issues/1) PRs welcome or comment on the issue if this is important for you.

## Features

- [Defining collections](#defining-collections)
- [Saving records](#saving-records)
- [Querying records](#querying-records)
- [Updating records](#updating-records)
- [Deleting records](#deleting-records)
- [Adding indices](#adding-indices)
- [Working with SQL](#working-with-sql)
- [Collations](#collations)
- [Concurrency and transactions](#concurrency-and-transactions)

## Defining collections

Record types are structs that conform to `Record`. All examples on this page use this example record type:

<!---defining-collections--->
```swift
struct Employee: Record {
    var id = UUID()
    var name: String
    var salary: Int
}
```

`Record` inherits from `Codable` and `Identifiable`, so all record types will get an automatic implementation of `Codable` and must have an id.

Under the hood, EasyDB is using `Codable` to get a list of the properties of this struct and generate a table with `id` and `name` columns. 

The table is created and migrated the first time the collection is accessed:

<!---create-collections--->
```swift
let database = EasyDB("my-database.sqlite")
let employees = try database.collection(Employee.self)
```

Most record types should just work but some - in particular any that have enums as properties - require a little extra code. See [Constraints on record types](#constraints-on-record-types).

### Primary keys

A unique index for `id` will automatically be added for all collections.

We recommend `UUID` for IDs, declared as `var id = UUID()` so that an ID is automatically generated when you create a new instance. If you need to integrate with other systems that expect a different ID format you can use `String`, `Int`, or any other type that is both `Codable` and `Hashable`.

Whatever the type of the `id` property, your application is responsible for generating ids. Developers who are used to working with relational databases may expect the database to generate an auto-incrementing integer ID. EasyDB does not support auto-incrementing IDs as they do not play nicely with Swift's type system.

## Saving records

The `save(_:)` method will ensure that a record is persisted to the database:

<!---save-one--->
```swift
try employees.save(Employee(name: "Peter Gibbons", salary: 40250))
```

`save(_:) is an "upsert" operation - it will insert a new record into the collection or update the existing data if a row with the same id already exists in the database:

<!---fetch-edit-save--->
```swift
// load a random Employee
if var row = try employees.all().orderBy("random()").fetchOne() {
    // reverse the words their name
    row.name = row.name.split(separator: " ").reversed().joined(separator: " ")
    // save the record
    try employees.save(row)
}
```

Save many records in a transaction. This is an atomic operation, if one save fails e.g. due to a unique constraint, no an error will be throws and no records will be saved.

<!---save-many--->
```swift
try employees.save([
    Employee(name: "Samir Nagheenanajar", salary: 40_250),
    Employee(name: "Michael Bolton", salary: 40_250),
    Employee(name: "Bill Lumbergh", salary: 110_000)
])
```

There is an alternative method `insert(_:)` which works just like `save(_:)` except that it will only insert, not update. An error will be thrown if you try to `insert` a record with the same `id` as an existing record.

## Querying records

The `QueryBuilder` API is a fluent API for defining and executing SQL queries: 

<!---query-filter--->
```swift
_ = try employees
    .filter(\.name, lessThanOrEqualTo: "b")
    .orderBy(\.name)
    .limit(3)
    .fetchMany()
//  ^^ SELECT * FROM MyRecord WHERE `name` <= 'b' ORDER BY `name` LIMIT 3
```

Use `fetchOne()` to get the first record.

Each call to `filter`, `orderBy` and `limit` returns a new immutable instance of `QueryBuilder`, so you can create and store filters then use them in different ways:

<!---query-shared--->
```swift
let filter = employees
    .filter(\.name, lessThanOrEqualTo: "b")
    .orderBy(\.name)

let count = try filter.fetchCount()
log("There are \(count) records in total")

let first10 = try filter.limit(10).fetchMany()
log("First 10: \(first10)")
```

This document describes most of the things you can do with the query API. For a full list, check out the inline documentation in XCode or read the source on GitHub: see the [Filterable protocol](https://github.com/BernieSumption/EasyDB/blob/master/Sources/EasyDB/Filterable.swift) for `filter(...)` methods and [QueryBuilder struct](https://github.com/BernieSumption/EasyDB/blob/master/Sources/EasyDB/QueryBuilder.swift) for all other methods

### Filtering with raw SQL

The filter API using key paths is convenient but it can't do everything. Sometimes you need the power of SQL:

<!---filter-sql--->
```swift
// select records where salary is even, though lord knows why
// you'd want to do that
_ = try employees.filter("\(\.salary) % 2 == 0").fetchMany()
//  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == 0
```

Note how the key path interpolated into the SQL string is converted into a column name. EasyDB uses string interpolation to prevent some errors and SQL injections vulnerabilities, see [working with SQL](#working-with-sql).

You can `orderBy` an SQL expression too:

<!---orderby-sql--->
```swift
_ = try employees.all().orderBy("\(\.salary) % 2").fetchMany()
//  ^^ SELECT * FROM MyRecord ORDER BY `count` % 2 == 0
```

### Adding custom filter extensions

If you use the same SQL filter in many places you can extend `Filterable` to add a Swift API method for it. Here's the above query for even numbers implemented as an extension:

<!---filter-sql-extension--->
```swift
extension Filterable {
    func filter<Value: Codable>(_ property: KeyPath<Row, Value>, isEven: Bool) -> QueryBuilder<Row> {
        return filter("\(property) % 2 == \(isEven ? 0 : 1)")
    }
}
```

Use it like this:

<!---filter-sql-extension-use--->
```swift
_ = try employees.filter(\.salary, isEven: true).fetchMany()
//  ^^ SELECT * FROM MyRecord WHERE `salary` % 2 == ?
```

Extensions can be added to `Filterable` or `QueryBuilder`. Prefer `Filterable` because these extension methods will be available on both `Collection` (e.g. `collection.yourNewMethod()`) `QueryBuilder` (e.g. `collection.all().yourNewMethod()`). Extensions to `QueryBuilder` are not available on collections, but have access to the full `QueryBuilder` API so can, for example, execute queries.

### Selecting partial records

The `fetchMany()` and `fetchOne()` methods return instances of the record type. If you don't need the whole instance you can improve CPU and memory performance by selecting individual fields.

You can select a single field using a key path:

<!---subset-query-single--->
```swift
let names = try employees.all().fetchMany(\.name)
//  ^^ SELECT `name` FROM `MyRecord`
// names is typed [String]
```

Or select a subset of fields using a custom result type. Only the fields present in the result type will be selected. This is not type-safe - the property names and types of the result type must match the record type, otherwise an error will be thrown.

<!---subset-query-multiple--->
```swift
struct NameAndId: Codable {
    var id: UUID
    var name: String
}
let namesAndIds = try employees.all().fetchMany(NameAndId.self)
//  ^^ SELECT `id`, `name` FROM `MyRecord`
// namesAndIds is typed [NameAndId]
```

## Updating records

The easiest way to update single a record is to fetch it from the database, modify it, and call `save(_:)`. But to update a record in bulk, or save a subset of fields of a single record, you can use the `QueryBuilder` API.

Update every record:

<!---update--->
```swift
try employees.all().update(\.name, "new-name")
//  ^^ UPDATE `MyRecord` SET `name` = ?
```

Update some records based on a filter:

<!---update-filter--->
```swift
try employees
    .filter(\.name, equalTo: "old-name")
    .update(\.name, "new-name")
//  ^^ UPDATE `MyRecord` SET `name` = ? WHERE `id` = ?
```

Apply multiple updates by chaining `updating(_:_:)`

<!---update-multiple--->
```swift
try employees
    .all()
    .updating(\.name, "new-name")
    .updating(\.id, UUID())
    .update()
//  ^^ UPDATE `MyRecord` SET `name` = ?, `id` = ?
```

If the key path API can not achieve what you need, you can use SQL. In this example, every record is incremented by 1:

<!---update-sql--->
```swift
try employees
    .all()
    .update("\(\.name) = \(\.name) + 1")
//  ^^ UPDATE `MyRecord` SET `name` = `name` + 1
```

See the docs for [working with SQL](#working-with-sql) for more information on how the SQL is handled.

## Deleting records

Deleting records works just like fetching, and can use the same set of filter operations to target the records to delete:

<!---deleting--->
```swift
try employees
    .filter(id: thatDudeWeGonnaFire)
    .delete()
```

## Adding indices

EasyDB supports regular and unique indices:

<!---indices--->
```swift
struct Book: Record {
    var id = UUID() // automatically unique
    @Unique var title: String
    @Index var author: String
    var price: Int
}
```

Attempting to insert a book with the same `id` or `name` as an existing book will result in an error. 

The `@Unique` attribute is only required on `name`. `id` is unique even without specifying a unique index.

### Compound and expression indices

Use `database.execute(_:)` to create custom indices:

<!---indices-custom--->
```swift
let books = try database.collection(Book.self)
try database.execute("""
    CREATE INDEX IF NOT EXISTS `book-title-author`
    ON \(books) (`title`, `author`)
""")
```

**IMPORTANT!** manually created indices are not automatically migrated, so if you need to change the SQL you must create a new index and remove the old: 

<!---indices-custom-migrate--->
```swift
try database.execute("""
    DROP INDEX IF EXISTS `book-title-author`
""")
try database.execute("""
    CREATE INDEX IF NOT EXISTS `book-title-asc-author-desc`
    ON \(books) (`title` ASC, `author` DESC)
""")
```

Automatic migrations for custom indices are [on the roadmap](https://github.com/BernieSumption/EasyDB/issues/5), PRs welcome or comment on the issue if this is important for you.

## Working with SQL

Previously you've seen how API methods like `filter` and `update` have overloads that take SQL fragments to be included in the generated SQL statement.

You can also execute whole SQL statements with the `execute` methods:

<!---execute-sql--->
```swift
let randomNumber = try database.execute(Int.self, "SELECT random()")

// or for statements that do not return a value
try database.execute("PRAGMA case_sensitive_like = true")
```

All methods that accept SQL do so as a string interpolation, not a `String`. You can't just pass any old String:

<!---manually-managed--->
```swift
let sql = "DELETE from Employees"
database.execute(sql)
// ^^ syntax error "Cannot convert value of type 'String'
//    to expected argument type"
```

Instead, use a string literal, optionally interpolating several kinds of value:

**Key paths** will be replaced in the query with a quoted property name. This only works collections.

<!---execute-sql-interpolation-key-path--->
```swift
try employees.filter("LENGTH(\(\.name)) < 5").delete()
//  ^^ DELETE FROM Employees where LENGTH(`name`) < 5
//     # fire all employees with short names
```

**Codable values** will be replaced with a parameter placeholder `?` and the value bound as a parameter to the query. This allows you to safely use strings without creating SQL injection vulnerabilities

<!---execute-sql-interpolation-string--->
```swift
let bobbyTables = "Robert'); DROP TABLE Employees;--"
try database.execute("DELETE from Employee WHERE `name` = \(bobbyTables)")
//  ^^ DELETE FROM Employees where `name` = ?
//     # "Robert'); DROP TABLE Employees;--" bound to parameter 1
//     # Fire Bobby. Nice try Bobby.
```

**SQL literals** require the `literal:` argument name and insert the string directly into the query. You are responsible for ensuring that this doesn't open up an SQL injection attack:

<!---execute-sql-interpolation-literal--->
```swift
let operation = lessThan ? "<" : ">"
try employees.filter("salary \(literal: operation) 50000").delete()
//  ^^ DELETE FROM Employees where salary < 50000
```

**Collections** will be replaces with the quoted table name:

<!---execute-sql-interpolation-collation--->
```swift
try database.execute("CREATE TABLE Tmp (col STRING COLLATE \(.caseInsensitive))")
//  ^^ CREATE TABLE Tmp (col STRING COLLATE `caseInsensitive`)
```

**Collations** will be replaced with the quoted table name and also registers the collation with SQLite so that it can be used. For this reason, always use this form rather than using the collation name directly in SQL:

<!---execute-sql-interpolation-collation--->
```swift
try database.execute("CREATE TABLE Tmp (col STRING COLLATE \(.caseInsensitive))")
//  ^^ CREATE TABLE Tmp (col STRING COLLATE `caseInsensitive`)
```

### Selecting into custom result types

The method `execute(ResultType.self, "query")` allows you to specify the result type. You can specify any Codable type and EasyDB will try to decode the query into it.

To read a single row, pass one of these kinds of type:

- **A primitive type** e.g. `String.self` or `Int.self` will return the first column of the first row of results and throw an error if there are no rows.
- **A `Codable` struct** e.g. `SomeStruct.self` will return a single row mapping column names in the query to property names. It is an error if `SomeStruct` contains a property that does not correspond to a column in the query results. It is not an error if the query results contain a column that does not correspond to a property in `SomeStruct` - that property will just be ignored.
- **A dictionary** e.g. `[String: String].self` will return the first row of results with column names in the query mapped to keys in the dictionary

To read multiple rows:

- **An array of the above** e.g. `[String].self`, `[SomeStruct].self` or `[[String: String]].self` will operate as above, except that all rows will be returned in an array.
- **A 2D array of primitive types** e.g. `[[String]].self` or `[[Int]].self`` will return all columns of all rows. Each row is an array of values in the order that they are returned by the query.

## Collations

A collation defines how EasyDB compares and sorts strings. The default `string` collation is case-sensitive so `"EasyDB"` is different from and sorted before `"easydb"`. Under the `caseInsensitive` collation those two strings are the same.

Set a collation for a property by adding a `@CollateXXX` annotation:

<!---collation-annotation--->
```swift
struct Book: Record {
    var id = UUID()
    var author: String
    @CollateCaseInsensitive var name: String
}

let books = try database.collection(Book.self)
try books.insert(Book(author: "Joseph Heller", name: "Catch 22"))
let count = try books.filter(\.name, equalTo: "CATCH 22").fetchCount()
XCTAssertEqual(count, 1)
```

Defining a collation on a column like this makes it the default wherever collations are used: in regular and unique indices, filtering and sorting.

It is possible to override the collation for filters and sorting:

<!---collation-annotation-override--->
```swift
let result = try books
    .filter(\.author, equalTo: "unknown", collation: .caseInsensitive)
    .orderBy(\.name, collation: .binary)
    .fetchMany()
```

### Built in collations

EasyDB ships with 4 collations:

- `.string` - The default collation sequence for EasyDB. Sorts strings case-sensitively using Swift's `==` and `<=` operators. Unicode-safe.
- `.caseInsensitive` - Sort unicode strings in a case-insensitive way using Swift's `String.caseInsensitiveCompare(_:)` function
- `.localized` - Sort unicode strings using localized comparison with Swift's `String.localizedCompare(_:)` function. This produces ordering similar to that when you get in the macOS Finder.
- `.localizedCaseInsensitive` - Sort unicode strings using case-insensitive localized comparison with Swift's `String.localizedCaseInsensitiveCompare(_:)` function
- `.binary` - The built-in SQLite `binary` collation that compares strings using their in-memory binary representation, regardless of text encoding. It is provided because some applications may _want_ to differentiate between equivalent but differently serialised unicode strings. But for most real applications it is not a good choice.

Use the `@CollateBinary`, `@CollateCaseInsensitive`, `@CollateLocalized`, `@CollateLocalizedCaseInsensitive` annotation to change the default collation on a property.

### Custom collations

If you have need for a custom collation, you can define one:

<!---custom-collation--->
```swift
extension Collation {
    /// Ignore string content and sort by length
    static let byLength = Collation("byLength") { (lhs, rhs) in
        if lhs.count == rhs.count {
            return .orderedSame
        }
        return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
    }
}
```

Use it like this:

<!---custom-collation-use--->
```swift
let results = try employees
    .all()
    .orderBy(\.name, collation: .byLength)
    .fetchMany()
```

To set your custom collation as the default for a property you need to define your own annotation property wrapper:

<!---custom-collation-annotation--->
```swift
@propertyWrapper
struct CollateByLength<Value: Codable & Equatable>: ConfigurationAnnotation {
    public var wrappedValue: Value

    public static var propertyConfig: PropertyConfig {
        return .collation(.byLength)
    }
}
```

And use it like this:

<!---custom-collation-annotation-use--->
```swift
struct Book: Record {
    var id = UUID()
    @CollateByLength var name: String
}
let books = try database.collection(Book.self)
let results = try books.all().orderBy(\.name).fetchMany()
//  ^^ results sorted by your custom collation
``` 

### Using collations in SQL

A collation can be used with a string interpolation anywhere that SQL is accepted:

<!---custom-collation-register--->
```swift
let results = try employees
    .filter("""
        \(\.name) COLLATE \(.byLength) = CAST(\(\.salary) AS TEXT) COLLATE \(.byLength)
    """)
    .fetchMany()
//  ^^ Select employees whose name is the same number of characters as the
//     of digits in their Salary. Hey it seems like an odd feature but I'm
//     sure the analysts know what they're doing when they asked for it?
```

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

Genuine multiple reader single writer concurrency using SQLite's WAL mode is [on the roadmap](https://github.com/BernieSumption/EasyDB/issues/2) and PRs are welcome or comment on the issue if this is important for you.

## Constraints on record types

You can probably ignore this section - most Codable types will just work, including all the data types that you'd typically want to store in a database (strings, numbers, booleans, arrays, structs, dictionaries etc). However, if you get an error thrown while creating a querying collection, it may be because your record type does not meet the requirements.

There are two constraints on record types:

1. Your record type should use the compiler-synthesised `Codable` implementation: do not implement your own `init(from:)` or `encode(to:)` functions (it is fine however for your record types to use other types that have their own `Codable` implementations).
2. The primitive data types used by your record type must implement `SampleValueSource` or be decodable from the strings `"0"` or `"1"`, or the numbers `0` or `1`, or the booleans `false` or `true`. Most enums will not meet this requirement.

The second requirement may seem a bit odd. First we'll show how to conform to `SampleValueSource`, then we'll explain why this is necessary.

### Adding support for enums and other unsupported value types

Here's an example of an unsupported `Codable` type. The enum `Direction` encodes as a string, but `"0"` is not a valid direction:

<!---invalid-record-type--->
```swift
struct Invalid: Record {
    var id = UUID()
    var direction: Direction
}
// "0" is not a valid value for this enum
enum Direction: String, Codable {
    case up, down, left, right
}
XCTAssertThrowsError(
    // message: Error thrown from Direction.init(from:) ... Cannot initialize
    //          Direction from invalid String value 0
    try database.collection(Invalid.self)
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

It does using `Codable` - it calls `YourRecordType.init(from: Decoder)`, passing a special Decoder instance that records how it is used. Your record type will ask the decoder for some data in the format that it expects. For example, if `YourRecordType` contains a property `var value: Int32` then `init(from: Decoder)` is going to ask the decoder for an `Int32` called `value` (specifically it will call `decoder.decode(Int32.self, forKey: "value")`). This is how EasyDB figures out the structure of Codable types. The decoder will respond by giving it a value of the kind requested: `"0"` or `"1"` for strings, `0` or `1` for numbers, `false` or `true` for booleans.

In the case of `Direction` in the example above, `Direction.init(from: Decoder)` will ask for a `String`, EasyDB will respond with `"0"`, and an error will be thrown because `"0"` is not a valid direction.

EasyDB extends a few common built-in types - `Date`, `Data`, `UUID` and `URL` - with conformance to `SampleValueSource`.

But if you use another type that encodes itself to a string but for which `"0"` or `"1"` are not valid representations, you will need to add `SampleValueSource` conformance yourself.

## Reasons not to use EasyDB

Even in its first release, EasyDB is the best iOS database for _my_ needs. But your needs may be different. If you need any of these features _now_ then use a different database. Bear in mind that it's not hard to migrate from EasyDB to any other SQLite-based database as they all use the same data file format, so if you don't require these features now but think you might in the future, you can use EasyDB knowing that you're not locked in.

**You want a Swift interface to the full SQL API.** EasyDB does not completely hide you from SQL. Its philosophy is to provide a type-safe API for 90% of use cases and provide access to raw SQL so that you still have the full power of SQLite at your disposal. Personally I think that writing SQL is fine and your tests should catch any SQL syntax errors. If you disagree, use SQLite.swift

**You want an explicit schema, constraints and migrations.** EasyDB follows the schemaless document database philosophy. The application is responsible for enforcing data consistency, and the database operates as a high-performance but "dumb" data store. You write less code because there is no need to define a schema or write migrations to evolve your schema between application versions. But fans of schema-driven databases regard the schema definition as "good repetition" - a kind of double-entry bookkeeping that helps you write reliable applications. If you want to define an explicit schema, use GRDB.

**You want to use advanced SQLite features.** EasyDB does not currently support the following features. There's no reason why it can't, it just doesn't yet:
  - _WAL mode:_ SQLite supports single-writer-multiple-reader concurrency via [WAL mode](https://www.sqlite.org/wal.html). Adding this to EasyDB is a high priority but for now EasyDB offers [thread safety but no concurrency](#concurrency-and-transactions). In fairness this is already better than Core Data which has neither concurrency nor thread safety.
  - _Change notification:_ SQLite can [notify you](https://sqlite.org/c3ref/update_hook.html) when your database is updated by another process. It is easy for your app to notify itself when it writes to the database, but if other processes may write to the same database file and you want to respond to those changes immediately, use GRDB. 
  - _custom builds:_ EasyDB uses the system-provided SQLite and you can not provide your own build, e.g. to use extensions like [SQLCipher](https://www.zetetic.net/sqlcipher/) or) [SpatiaLite](https://www.gaia-gis.it/fossil/libspatialite/index).
  - _Full-text search_: You can use full text search with EasyDB by writing your own SQL to define FTS virtual tables, but EasyDB does not provide an API to help you. 
