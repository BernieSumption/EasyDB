import Foundation

private let sampleValues = SampleValueIterator()

/// Produces a grid of binary values where there are enough rows to ensure that each column is unique.
/// For example if asked to produce five columns, there will be 3 rows:
///
/// ```
/// [
///   [0, 1, 0, 1, 0],
///   [0, 0, 1, 1, 0],
///   [0, 0, 0, 0, 1],
/// ]
/// ```
class MultifariousValues {
    private var item = 0
    private var runLength = 1
    private(set) var hasFinished = false

    func next<T>(_ type: T.Type) -> T? {
        guard let samples = sampleValues.get(type) else {
            return nil
        }
        let index = (item / runLength) % 2
        item += 1
        return index == 0 ? samples.0 : samples.1
    }

    func nextRow() {
        let didRollOver = runLength * 2 < item
        if didRollOver {
            runLength *= 2
        } else {
            hasFinished = true
        }
        item = 0
    }
}

private func debugValuesEncodeDifferently<T1: Encodable, T2: Encodable>(_ first: T1, _ second: T2)
    -> Bool
{
    do {
        return try Encoded(first) != Encoded(second)
    } catch {
        assert(false, "Error encoding values to check equality: \(error)")
        return false
    }
}

private class SampleValueIterator {
    private var typeToSamples = [ObjectIdentifier: (Any, Any)]()

    init() {
        setSampleValues(false, true)
        setSampleValues("0", "1")
        setSampleValues(Double(0), Double(1))
        setSampleValues(Float(0), Float(1))
        setSampleValues(Int(0), Int(1))
        setSampleValues(Int8(0), Int8(1))
        setSampleValues(Int16(0), Int16(1))
        setSampleValues(Int32(0), Int32(1))
        setSampleValues(Int64(0), Int64(1))
        setSampleValues(UInt(0), UInt(1))
        setSampleValues(UInt8(0), UInt8(1))
        setSampleValues(UInt16(0), UInt16(1))
        setSampleValues(UInt32(0), UInt32(1))
        setSampleValues(UInt64(0), UInt64(1))
        setSampleValues(Decimal(0), Decimal(1))
    }

    func setSampleValues<T: Encodable>(_ zero: T, _ one: T) {
        assert(debugValuesEncodeDifferently(zero, one), "sample values must be different")
        assert(
            debugValuesEncodeDifferently(zero, 1),
            "a sample value for zero must not encode as `1`!")
        assert(
            debugValuesEncodeDifferently(zero, "1"),
            "a sample value for zero must not encode as `1`!")
        assert(
            debugValuesEncodeDifferently(one, 0),
            "A sample value for one must not encode as `0`!")
        assert(
            debugValuesEncodeDifferently(one, "0"),
            "A sample value for one must not encode as `0`!")
        typeToSamples[ObjectIdentifier(T.self)] = (zero, one)
    }

    func get<T>(_ type: T.Type) -> (T, T)? {
        if let cached = getFromCache(type) {
            return cached
        }

        guard let source = type as? SampleValueSource.Type else {
            return nil
        }

        source.sampleValues.provide(self)

        let samples = getFromCache(type)

        assert(samples != nil, "\(type).provideSampleValues did not provide samples of the correct type")

        return samples
    }

    private func getFromCache<T>(_ type: T.Type) -> (T, T)? {
        let cacheRecord = typeToSamples[ObjectIdentifier(type)]
        if let cached = cacheRecord as? (T, T) {
            return cached
        }
        assert(cacheRecord == nil, "cached samples are of wrong type")
        return nil
    }
}

/// A protocol for types that provide two sample values, allowing them to participate in codable structure discovery
///
/// Note: EasyDB will attempt to automatically generate sample values for most codable types. Conform to this
/// protocol only if the automatic process doesn't work. See [codable structure discovery](TODO: url)
public protocol SampleValueSource {
    static var sampleValues: SampleValues { get }
}

/// Used by `SampleValueSource` during [codable structure discovery](TODO: url)
public struct SampleValues {
    fileprivate let provide: (SampleValueIterator) -> Void

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
