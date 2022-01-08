
public struct Collection<T: Codable> {
    private let database: Database
    
    internal init(_ type: T.Type, _ database: Database) {
        self.database = database
    }
}
