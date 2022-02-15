import Foundation

enum ParameterValue: Equatable {
    case double(Double)
    case int(Int64)
    case null
    case text(String)
    case blob(Data)
    
    init(_ value: Bool) {
        self = .int(value ? 1 : 0)
    }
    
    init(_ value: String) {
        self = .text(value)
    }
    
    init(_ value: Double) {
        self = .double(value)
    }
    
    init(_ value: Float) {
        self = .double(Double(value))
    }
    
    init(_ value: Float16) {
        self = .double(Double(value))
    }
    
    init(_ value: Int) {
        self = .int(Int64(value))
    }
    
    init(_ value: Int8) {
        self = .int(Int64(value))
    }
    
    init(_ value: Int16) {
        self = .int(Int64(value))
    }
    
    init(_ value: Int32) {
        self = .int(Int64(value))
    }
    
    init(_ value: Int64) {
        self = .int(value)
    }
    
    init(_ value: UInt) {
        // allow 64 bit unsigned integer to overflow - the decoder will reverse it
        self = .int(Int64(truncatingIfNeeded: value))
    }
    
    init(_ value: UInt8) {
        self = .int(Int64(value))
    }
    
    init(_ value: UInt16) {
        self = .int(Int64(value))
    }
    
    init(_ value: UInt32) {
        self = .int(Int64(value))
    }
    
    init(_ value: UInt64) {
        // allow 64 bit unsigned integer to overflow - the decoder will reverse it
        self = .int(Int64(truncatingIfNeeded: value))
    }
    
    init(_ value: Date) {
        let encoded = iso8601Formatter.string(from: value)
            .trimmingCharacters(in: .letters) // remove time zone
        self = .text(encoded)
    }
    
    init(_ value: Data) {
        self = .blob(value)
    }
}
