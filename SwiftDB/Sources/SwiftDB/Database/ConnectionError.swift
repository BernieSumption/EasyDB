
public struct ConnectionError: Error, CustomStringConvertible {
    public let resultCode: ResultCode
    public let message: String?
    public let sql: String?
    
    public var description: String {
        "\(resultCode) \(message ?? "(no message)"); while executing \"\(sql ?? "(no query)")\""
    }
}
