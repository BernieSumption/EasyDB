
struct ConnectionError: Error, CustomStringConvertible {
    let resultCode: ResultCode
    let lastMessage: String?
    let sql: String?
    
    var description: String {
        "\(resultCode) (Last SQLite message: \(lastMessage ?? "none"); Query: \(sql ?? "none")"
    }
}
