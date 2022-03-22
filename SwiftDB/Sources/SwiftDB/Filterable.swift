
public protocol Filterable {
    associatedtype Row: Codable
    
    /// Add an SQL filter using string interpolation to provide parameters. String interpolation is used to
    /// provide parameters safely (i.e. without the possibility of SQL injection). This low-level method is
    /// useful to construct complex SQL filters e.g. by invoking SQLite functions.
    ///
    /// For example `filter("replace(foo, '-', '') = \(myString)")` will append
    /// `WHERE replace(foo, '-', '') = ?` to the SQL query and bind `myString` as a parameter
    ///
    /// The optional `collate` parameter defines a collating sequence for the
    func filter(_ sqlFragment: SQLFragment<Row>, collate: Collation?) -> QueryBuilder<Row>
    
    /// Equivalent to `filter(sqlFragment, collate: nil)`
    func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row>
}

extension Filterable {
    /// Select records where `property == value`.
    ///
    /// This uses the SQL `IS` operator which has the same semantics as Swift's `==` when comparing null values
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, is value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) IS \(value)", collate: collate)
    }

    /// Select records where `property != value`.
    ///
    /// This uses the SQL `IS NOT` operator which has the same semantics as Swift's `!=` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNot value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) IS NOT \(value)", collate: collate)
    }

    /// Select records where `property > value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThan value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) > \(value)", collate: collate)
    }

    /// Select records where `property < value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThan value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) < \(value)", collate: collate)
    }

    /// Select records where `property >= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThanOrEqualTo value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) >= \(value)", collate: collate)
    }

    /// Select records where `property <= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThanOrEqualTo value: V, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter("\(property) <= \(value)", collate: collate)
    }

    /// Select records where `property ISNULL` (if `isNull` is `true`) or `property NOTNULL` otherwise
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool, collate: Collation? = nil) -> QueryBuilder<Row> {
        return filter(isNull ? "\(property) ISNULL" : "\(property) NOTNULL", collate: collate)
    }

    /// Select records where `property LIKE value`
    public func filter(_ property: KeyPath<Row, String>, like: String) -> QueryBuilder<Row> {
        return filter("\(property) LIKE \(like)")
    }

    /// Select records where `property NOT LIKE value`
    public func filter(_ property: KeyPath<Row, String>, notLike: String) -> QueryBuilder<Row> {
        return filter("\(property) NOT LIKE \(notLike)")
    }
}
