import Foundation

public struct QueryBuilder<Row: Codable>: Filterable {
    private let collection: Collection<Row>
    private var filters = [Filter]()
    private var orders = [Order]()
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
    
    public func limit(_ limit: Int) -> Self {
        var copy = self
        copy.limit = limit
        return copy
    }
    
    enum CompileMode {
        case select
        case delete
    }
    
    private func compile(_ mode: CompileMode) throws -> CompileResult {
        var parameters = [DatabaseValue]()
        var sql = SQL()
        switch mode {
        case .select:
            sql = sql
                .select()
                .quotedNames(collection.columns)
                .from(collection.table)
        case .delete:
            sql = sql
                .delete()
                .from(collection.table)
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
