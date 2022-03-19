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


/// Define a sorting order for strings
public struct Collation {
    /// The built-in SQLite BINARY collation that compares strings using their in-memory binary representation,
    /// regardless of text encoding. This is the default unless an alternative is specified.
    public static let binary = Collation("BINARY")
    
    /// The built-in SQLite NOCASE collation that considers ASCII lowercase and uppercase letters to be equivalent
    /// but does not handle unicode case insensitivity
    public static let asciiCaseInsensitive = Collation("NOCASE")
    
    /// The built-in SQLite RTRIM collation - as `.binary` but ignoring trailing whitespace
    public static let rtrim = Collation("RTRIM")
    
    let name: String
    let compare: ((Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> ComparisonResult)?
    
    /// Create a collation function with a comparison function
    public init(_ name: String, _ compare: @escaping (String, String) -> ComparisonResult) {
        self.name = name
        self.compare = { (length1, buffer1, length2, buffer2) in
            let string1 = buffer1.unsafelyUnwrapped.toString(length: Int(length1)).unsafelyUnwrapped
            let string2 = buffer2.unsafelyUnwrapped.toString(length: Int(length2)).unsafelyUnwrapped
            return compare(string1, string2)
        }
    }
    
    /// Create a collation function with a name. It should already exist in the database.
    public init(_ name: String) {
        self.name = name
        self.compare = nil
    }
}

private extension UnsafeRawPointer {
    func toString(length: Int) -> String? {
        return String(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: self),
            length: length,
            encoding: .utf8,
            freeWhenDone: false)
    }
}

extension Collation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
    }
    
    /// Two collations are equal if they share the same name (case insensitive)
    /// :nodoc:
    public static func == (lhs: Collation, rhs: Collation) -> Bool {
        // See <https://www.sqlite.org/c3ref/create_collation.html>
        return lhs.name.caseInsensitiveCompare(rhs.name) == .orderedSame
    }
}
