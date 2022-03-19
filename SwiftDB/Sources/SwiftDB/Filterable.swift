
public protocol Filterable {
    associatedtype Row: Codable
    
    /// Add an SQL filter using string interpolation to provide parameters. String interpolation is used to
    /// provide parameters safely (i.e. without the possibility of SQL injection). This low-level method is
    /// useful to construct complex SQL filters e.g. by invoking SQLite functions.
    ///
    /// For example `filter("replace(foo, '-', '') = \(myString)")` will append
    /// `WHERE replace(foo, '-', '') = ?` to the SQL query and bind `myString` as a parameter
    func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row>
}

extension Filterable {
    /// Select records where `property == value`.
    ///
    /// This uses the SQL `IS` operator which has the same semantics as Swift's `==` when comparing null values
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, is value: V) -> QueryBuilder<Row> {
        return filter("\(property) IS \(value)")
    }

    /// Select records where `property != value`.
    ///
    /// This uses the SQL `IS NOT` operator which has the same semantics as Swift's `!=` when comparing null values.
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNot value: V) -> QueryBuilder<Row> {
        return filter("\(property) IS NOT \(value)")
    }

    /// Select records where `property > value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThan value: V) -> QueryBuilder<Row> {
        return filter("\(property) > \(value)")
    }

    /// Select records where `property < value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThan value: V) -> QueryBuilder<Row> {
        return filter("\(property) < \(value)")
    }

    /// Select records where `property >= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, greaterThanOrEqualTo value: V) -> QueryBuilder<Row> {
        return filter("\(property) >= \(value)")
    }

    /// Select records where `property <= value`
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, lessThanOrEqualTo value: V) -> QueryBuilder<Row> {
        return filter("\(property) <= \(value)")
    }

    /// Select records where `property IS NULL` (if `isNull` is `true`) or `property IS NOT NULL` otherwise
    public func filter<V: Codable>(_ property: KeyPath<Row, V>, isNull: Bool) -> QueryBuilder<Row> {
        return filter(isNull ? "\(property) IS NULL" : "\(property) IS NOT NULL")
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
