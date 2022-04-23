import Foundation

/// A protocol for types that provide two sample values, allowing them to participate in codable structure discovery
///
/// Note: EasyDB will attempt to automatically generate sample values for most codable types. Conform to this
/// protocol only if the automatic process doesn't work. See
/// [constraints on record types](https://github.com/BernieSumption/EasyDB#constraints-on-record-types).
public protocol SampleValueSource {
    static var sampleValues: SampleValues { get }
}

/// A holder for two codable values of the same type
public struct SampleValues {
    let provide: (SampleValueIterator) -> Void

    public init<T: Codable>(_ zero: T, _ one: T) {
        self.provide = { $0.setSampleValues(zero, one) }
    }

    fileprivate func provideSampleValues(_ iterator: SampleValueIterator) {
        provide(iterator)
    }
}

extension URL: SampleValueSource {
    static public var sampleValues = SampleValues(
        URL(string: "data:,0")!,
        URL(string: "data:,1")!)
}

extension UUID: SampleValueSource {
    static public var sampleValues = SampleValues(
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
}

extension Date: SampleValueSource {
    static public var sampleValues = SampleValues(
        Date(timeIntervalSince1970: 0),
        Date(timeIntervalSince1970: 1))
}

extension Data: SampleValueSource {
    static public var sampleValues = SampleValues(
        Data(repeating: 0, count: 1),
        Data(repeating: 1, count: 1))
}
