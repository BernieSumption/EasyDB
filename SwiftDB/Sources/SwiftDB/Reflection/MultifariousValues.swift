import Foundation

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

    private var typeToSamples = [ObjectIdentifier: (Any, Any)]()

    init() {
        setSampleValues(zero: false, one: true)
        setSampleValues(zero: "0", one: "1")
        setSampleValues(zero: Double(0), one: Double(1))
        setSampleValues(zero: Float(0), one: Float(1))
        setSampleValues(zero: Int(0), one: Int(1))
        setSampleValues(zero: Int8(0), one: Int8(1))
        setSampleValues(zero: Int16(0), one: Int16(1))
        setSampleValues(zero: Int32(0), one: Int32(1))
        setSampleValues(zero: Int64(0), one: Int64(1))
        setSampleValues(zero: UInt(0), one: UInt(1))
        setSampleValues(zero: UInt8(0), one: UInt8(1))
        setSampleValues(zero: UInt16(0), one: UInt16(1))
        setSampleValues(zero: UInt32(0), one: UInt32(1))
        setSampleValues(zero: UInt64(0), one: UInt64(1))
        setSampleValues(zero: Decimal(0), one: Decimal(1))
        setSampleValues(
            zero: URL(string: "data:,0")!,
            one: URL(string: "data:,1")!)
        setSampleValues(
            zero: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
            one: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
        setSampleValues(
            zero: Date(timeIntervalSince1970: 0),
            one: Date(timeIntervalSince1970: 1))
        setSampleValues(
            zero: Data(repeating: 0, count: 1),
            one: Data(repeating: 1, count: 1))
        reset()
    }

    func setSampleValues<T: Encodable>(zero: T, one: T) {
        assert(__debug__valuesEncodeDifferently(zero, one), "sample values must be different")
        assert(
            __debug__valuesEncodeDifferently(zero, 1),
            "a sample value for zero must not encode as `1`!")
        assert(
            __debug__valuesEncodeDifferently(zero, "1"),
            "a sample value for zero must not encode as `1`!")
        assert(
            __debug__valuesEncodeDifferently(one, 0),
            "A sample value for one must not encode as `0`!")
        assert(
            __debug__valuesEncodeDifferently(one, "0"),
            "A sample value for one must not encode as `0`!")
        typeToSamples[ObjectIdentifier(T.self)] = (zero, one)
    }

    func next<T>(_ type: T.Type) -> T? {
        guard let values = typeToSamples[ObjectIdentifier(type)] as? (T, T) else {
            return nil
        }
        let index = (item / runLength) % 2
        item += 1
        return index == 0 ? values.0 : values.1
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

    func reset() {
        item = 0
        runLength = 1
        hasFinished = false
    }
}

private func __debug__valuesEncodeDifferently<T1: Encodable, T2: Encodable>(_ a: T1, _ b: T2)
    -> Bool
{
    do {
        let a = try JSON(encoding: a)
        let b = try JSON(encoding: b)
        return a != b
    } catch {
        assert(false, "Error encoding values to check equality: \(error)")
    }
}
