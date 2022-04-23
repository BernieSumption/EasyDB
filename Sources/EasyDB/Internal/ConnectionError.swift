struct ConnectionError: Error, CustomStringConvertible {
    let resultCode: ResultCode
    let message: String?
    let sql: String?

    var description: String {
        "\(resultCode) \(message ?? "(no message)"); while executing \"\(sql ?? "(no query)")\""
    }
}
