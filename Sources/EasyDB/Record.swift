public protocol Record: Codable, Identifiable where Self.ID: Codable {

    /// The table name for this record type. A default implementation is provided that uses the type name.
    static var tableName: String { get }
}

public extension Record {
    static var tableName: String {
        String(describing: Self.self)
    }
}
