import Foundation

public struct QueryBuilder<Row: Codable>: Filterable {
    private let collection: Collection<Row>
    private var filters = [Filter]()
    private var orders = [Order]()
    private var updates = [SQLFragment<Row>]()
    private var limit: Int?
    
    internal init(_ collection: Collection<Row>) {
        self.collection = collection
    }
    
    public func fetchOne() throws -> Row? {
        let query = try limit(1).compile(.select)
        let rows = try getConnection().execute(
            [Row].self, sql: query.sql, parameters: query.parameters)
        return rows.first
    }
    
    public func fetchMany() throws -> [Row] {
        let query = try compile(.select)
        return try getConnection().execute(
            [Row].self, sql: query.sql, parameters: query.parameters)
    }
    
    public func fetchCount() throws -> Int {
        let query = try compile(.count)
        return try getConnection().execute(
            Int.self, sql: query.sql, parameters: query.parameters)
    }
    
    public func delete() throws {
        let query = try compile(.delete)
        try getConnection().execute(sql: query.sql, parameters: query.parameters)
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>, collation: Collation?) -> Self {
        var copy = self
        copy.filters.append(Filter(sqlFragment: sqlFragment, collation: collation))
        return copy
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> Self {
        return filter(sqlFragment, collation: nil)
    }
    
    /// Change the order in which results are returned
    ///
    /// - Parameters:
    ///   - keyPath: the property t order by
    ///   - direction: `.ascending` (lower values first) or `.descending` (lower values last)
    ///   - collation: The collating sequence to use, e.g. `.caseInsensitive` to ignore case while sorting. Note:
    ///                is is possible to set a default collation on a field while configuring a collation. Only use this option
    ///                when you need to order by a different field to the default.
    ///   - nulls: where nulls should appear in the sorted result, `.first` or `.last`
    public func orderBy<T: Codable>(
        _ keyPath: KeyPath<Row, T>,
        _ direction: Direction? = nil,
        collation: Collation? = nil,
        nulls: Nulls? = nil
    ) -> QueryBuilder<Row> {
        var copy = self
        let collation = collation ?? collection.defaultCollation(for: keyPath)
        copy.orders.append(
            Order(keyPath: PartialCodableKeyPath(keyPath), direction: direction, collation: collation, nulls: nulls))
        return copy
    }
    
    /// Add an SQL `LIMIT` clause to this query, limiting the number of rows that will be fetched, updated or deleted
    public func limit(_ limit: Int) -> Self {
        var copy = self
        copy.limit = limit
        return copy
    }
    
    /// Append an update clause that sets `property = value` but do not execute the update yet.
    ///
    /// Call `update()` on the return value to execute the update.
    ///
    /// Multiple update clauses can be added by chaining function calls: `updating(...).updating(...).update()`.
    public func updating<V: Codable>(_ property: KeyPath<Row, V>, _ value: V) -> Self {
        return updating("\(property) = \(value)")
    }
    
    /// Append an SQL update clause but do not execute the update yet. , e.g. `.updating("\(\.a) = \(\.a) + 1")`
    /// will increment the value of `a` by 1.
    ///
    /// Call `update()` on the return value to execute the update.
    ///
    /// Multiple update clauses can be added by chaining function calls: `updating(...).updating(...).update()`.
    public func updating(_ sqlFragment: SQLFragment<Row>) -> Self {
        var copy = self
        copy.updates.append(sqlFragment)
        return copy
    }
    
    /// Append an update clause that sets `property = value` and execute the update.
    public func update<V: Codable>(_ property: KeyPath<Row, V>, _ value: V) throws {
        try updating(property, value).update()
    }
    
    /// Append an SQL update clause and execute the update, e.g. `.updating("\(\.a) = \(\.a) + 1")` will increment the value of `a` by 1.
    public func update(_ sqlFragment: SQLFragment<Row>) throws {
        try updating(sqlFragment).update()
    }
    
    /// Execute an update query. Values to update should have been set using `updating(...)`.
    public func update() throws {
        if updates.count == 0 {
            return
        }
        let query = try compile(.update)
        return try getConnection().execute(sql: query.sql, parameters: query.parameters)
    }
    
    enum CompileMode {
        case select
        case delete
        case count
        case update
    }
    
    private func compile(_ mode: CompileMode) throws -> CompileResult {
        var parameters = [DatabaseValue]()
        var sql = SQL()
        switch mode {
        case .select:
            sql = sql
                .raw("SELECT")
                .quotedNames(collection.columns)
                .raw("FROM")
                .quotedName(collection.table)
        case .delete:
            sql = sql
                .raw("DELETE FROM")
                .quotedName(collection.table)
        case .count:
            sql = sql
                .raw("SELECT COUNT(*) FROM")
                .quotedName(collection.table)
        case .update:
            sql = sql
                .raw("UPDATE")
                .quotedName(collection.table)
                .raw("SET")
            for update in updates {
                sql = sql.raw(try update.sql(collations: nil, overrideCollation: nil))
                parameters.append(contentsOf: try update.parameters())
            }
        }
        
        let connection = try getConnection()
        
        if !filters.isEmpty {
            sql = sql
                .raw("WHERE")
                .raw(
                    try filters
                        .map({ try $0.sql(collection) })
                        .joined(separator: " AND ")
                )
            
            for filter in filters {
                parameters += try filter.sqlFragment.parameters()
                if let collation = filter.collation {
                    connection.registerCollation(collation)
                }
            }
        }
        
        if !orders.isEmpty {
            sql = sql
                .raw("ORDER BY")
                .raw(
                    try orders
                        .map({ try $0.sql() })
                        .joined(separator: ", ")
                )
        }
        
        for order in orders {
            if let collation = order.collation {
                connection.registerCollation(collation)
            }
        }
        
        if let limit = limit {
            sql = sql.limit(limit)
        }
        
        return CompileResult(sql: sql.text, parameters: parameters)
    }
    
    struct Filter {
        let sqlFragment: SQLFragment<Row>
        let collation: Collation?
        
        func sql(_ collection: Collection<Row>) throws -> String {
            return try sqlFragment.sql(collations: collection, overrideCollation: collation)
        }
    }
    
    struct Order {
        let keyPath: PartialCodableKeyPath<Row>
        let direction: Direction?
        let collation: Collation?
        let nulls: Nulls?
        
        func sql() throws -> String {
            var sql = try keyPath.nameExpression(operation: "ordering")
            if let collation = collation {
                sql += " COLLATE "
                sql += SQL.quoteName(collation.name)
            }
            if let direction = direction {
                sql += " "
                sql += direction.name
            }
            if let nulls = nulls {
                sql += " NULLS "
                sql += nulls.name
            }
            return sql
        }
    }
    
    /// Define a sort order
    public enum Direction {
        /// Lower values come first
        case ascending
        /// Higher values come first
        case descending
        
        var name: String {
            switch self {
            case .ascending:
                return "ASC"
            case .descending:
                return "DESC"
            }
        }
    }
    
    /// Define a sorting order for NULL values
    public enum Nulls {
        /// NULL values should sort before other values
        case first
        /// NULL values should sort after other values
        case last
        
        var name: String {
            switch self {
            case .first:
                return "FIRST"
            case .last:
                return "LAST"
            }
        }
    }
    
    private struct CompileResult {
        let sql: String
        let parameters: [DatabaseValue]
    }
    
    private func getConnection() throws -> Connection {
        return try collection.database.getConnection()
    }
}

public protocol UpdateQueryBuilder {
    associatedtype Row
    
    /// Add a field to update
    func updating<V: Codable>(_ property: KeyPath<Row, V>, _ value: V) -> Self
    
    /// Add a field to update and execute the update. This is shorthand for `updating()`
    func update<V: Codable>(_ property: KeyPath<Row, V>, _ value: V) throws
    
    /// Execute an update. Values to update should have been set using `updating(_:_)`
    func update()
}
