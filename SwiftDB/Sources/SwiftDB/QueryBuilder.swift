import Foundation

public struct QueryBuilder<Row: Codable>: Filterable {
    private let collection: Collection<Row>
    private var filters = [SQLFragment<Row>]()
    private var orders = [Order]()
    
    internal init(_ collection: Collection<Row>) {
        self.collection = collection
    }
    
    public func fetchOne() throws -> Row? {
        let rows = try StatementDecoder.decode([Row].self, from: prepare(), maxRows: 1)
        return rows.first
    }
    
    public func fetchMany() throws -> [Row] {
        return try StatementDecoder.decode([Row].self, from: prepare())
    }
    
    public func filter(_ sqlFragment: SQLFragment<Row>) -> QueryBuilder<Row> {
        var copy = self
        copy.filters.append(sqlFragment)
        return copy
    }
    
    public func orderBy<T: Codable>(
        _ keyPath: KeyPath<Row, T>,
        _ direction: Direction? = nil,
        collate: Collation? = nil,
        nulls: Nulls? = nil
    ) -> QueryBuilder<Row> {
        var copy = self
        copy.orders.append(
            Order(keyPath: PartialCodableKeyPath(keyPath), direction: direction, collation: collate, nulls: nulls))
        return copy
    }
    
    private func prepare() throws -> Statement {
        var parameters = [DatabaseValue]()
        var sql = SQL()
            .select()
            .quotedNames(collection.columns)
            .from(collection.table)
        
        if !filters.isEmpty {
            sql = sql
                .raw("WHERE")
                .raw(
                    try filters
                        .map({ try $0.sql() })
                        .joined(separator: " AND ")
                )
            
            for filter in filters {
                parameters += try filter.parameters()
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
                collection.connection.registerCollation(collation)
            }
        }
            
        let statement = try collection.connection.prepare(sql: sql.text)
        for (index, parameter) in parameters.enumerated() {
            try statement.bind(parameter, to: index + 1)
        }
        return statement
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
                sql += collation.name
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
}
