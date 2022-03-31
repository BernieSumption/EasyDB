public protocol Filterable {
    associatedtype Row: Codable

    /// Add an SQL filter using string interpolation to provide parameters. String interpolation is used to
    /// provide parameters safely (i.e. without the possibility of SQL injection). This low-level method is
    /// useful to construct complex SQL filters e.g. by invoking SQLite functions.
    ///
    /// For example `filter("replace(foo, '-', '') = \(myString)")` will append
    /// `WHERE replace(foo, '-', '') = ?` to the SQL query and bind `myString` as a parameter
    ///
    /// The optional `collation` parameter defines a collating sequence for the
    func filter(_ sqlFragment: SQLFragment<Row>, collation: Collation?) -> QueryBuilder<Row>

    /// Equivalent to `filter(sqlFragment, collation: nil)`
    func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row>
}

extension Filterable {
    /// Add a filter limiting the query to records where `property == value`.
    ///
    /// This uses the SQL `IS` operator which has the same semantics as Swift's `==` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, equalTo value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) IS \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property != value`.
    ///
    /// This uses the SQL `IS NOT` operator which has the same semantics as Swift's `!=` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, notEqualTo value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) IS NOT \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property > value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThan value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) > \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property < value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThan value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) < \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property >= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThanOrEqualTo value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) >= \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property <= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThanOrEqualTo value: V, collation: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) <= \(value)", collation: collation)
    }

    /// Add a filter limiting the query to records where `property` is (or is not) `nil` 
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool) -> QueryBuilder<Row> {
        return filter(isNull ? "\(property) ISNULL" : "\(property) NOTNULL")
    }

    /// Select records where `property` matches `pattern` using the SQL `LIKE` operator.
    /// Matching of ASCII characters is case-insensitive, `_` matches any character and `%` matches any
    /// string of characters.
    public func filter(_ property: KeyPath<Row, String>, like pattern: String) -> QueryBuilder<Row> {
        return filter("\(property) LIKE \(pattern)")
    }

    /// Select records where `property` does not match `pattern` using the SQL `LIKE` operator.
    /// Matching of ASCII characters is case-insensitive, `_` matches any character and `%` matches any
    /// string of characters.
    public func filter(_ property: KeyPath<Row, String>, notLike pattern: String) -> QueryBuilder<Row> {
        return filter("\(property) NOT LIKE \(pattern)")
    }
}

extension Filterable where Row: Identifiable, Row.ID: Codable {
    /// Select records whose `id` property is equal to the provided value
    public func filter(id: Row.ID) -> QueryBuilder<Row> {
        return filter(\.id, equalTo: id)
    }
}
