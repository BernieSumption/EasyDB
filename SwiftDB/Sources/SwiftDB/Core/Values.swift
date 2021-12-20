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

struct NumericValues<T: Numeric>: Values {
    typealias Element = T

    init(_ type: T.Type) {}

    var count: Int { 128 }  // safe count for the smallest numeric type - Int8

    subscript(index: Int) -> T {
        (T.zero + 1) * T(exactly: index)!
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
