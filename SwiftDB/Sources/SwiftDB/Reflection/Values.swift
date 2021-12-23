protocol Values {
    associatedtype Element

    var count: Int { get }
    subscript(index: Int) -> Element { get }
}

struct ArrayOfValues<T>: Values {
    typealias Element = T
    let values: [T]

    init(_ values: [T]) {
        self.values = values
    }

    var count: Int { values.count }

    subscript(index: Int) -> T { values[index] }
}

struct NumericValues: Values {
    var count: Int { 128 }

    subscript(index: Int) -> Int8 {
        return Int8(exactly: index)!
    }
}

/// A type-erased `Values` instance
struct AnyValues {
    let count: Int
    let element: (Int) -> Any

    init<V: Values, E>(_ values: V) where V.Element == E {
        self.count = values.count
        self.element = { (index: Int) -> Any in
            values[index]
        }
    }

    subscript(index: Int) -> Any { element(index) }
}

/// A type-erased type
struct AnyType: Hashable {

    private let type: Any.Type

    init(_ type: Any.Type) {
        self.type = type
    }

    static func == (lhs: AnyType, rhs: AnyType) -> Bool {
        return lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(type).hash(into: &hasher)
    }
}

/// Cycles through each value of a `Values` producing a grid of values where there are
/// enough rows to ensure that each column is unique. For example if asked to produce five
/// columns for a `Values` with 2 elements `0` and `1`, the counter will produce 3 rows:
/// ```
/// [
///   [0, 1, 0, 1, 0],
///   [0, 0, 1, 1, 0],
///   [0, 0, 0, 0, 1],
/// ]
/// ```
class ValueCycler {
    private let values: AnyValues

    private var item = 0
    private var runLength = 1
    private(set) var hasFinished = false

    init(_ values: AnyValues) {
        self.values = values
    }

    func nextRow() {
        if didRollOver {
            runLength *= values.count
        } else {
            hasFinished = true
        }
        item = 0
    }

    func next() -> Any {
        guard !hasFinished else {
            return values[0]
        }
        let index = (item / runLength) % values.count
        item += 1
        return values[index]
    }

    /// Whether we ran out of values and started again from the first value since the last call to `nextRow`
    private var didRollOver: Bool {
        runLength * values.count < item
    }
}
