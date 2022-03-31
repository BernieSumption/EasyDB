import XCTest
import SwiftDB

class SortingTests: SwiftDBTestCase {

    func testOrderBy() throws {
        try assertFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value) },
            [1, 2, 3])
    }

    func testOrderByCustomSQL() throws {
        try assertFilter(
            [1, 6, 2, 5, 3, 4],
            // even numbers first, then by numeric order
            { $0.all().orderBy("\(\.value) % \(2), \(\.value)") },
            [2, 4, 6, 1, 3, 5])
    }

    func testOrderByDirection() throws {
        try assertFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value, .ascending) },
            [1, 2, 3])

        try assertFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value, .descending) },
            [3, 2, 1])
    }

    func testOrderByNulls() throws {
        try assertFilter(
            [1, nil, 2, nil, 3],
            { $0.all().orderBy(\.value, .descending, nulls: .first) },
            [nil, nil, 3, 2, 1])

        try assertFilter(
            [1, nil, 2, nil, 3],
            { $0.all().orderBy(\.value, .descending, nulls: .last) },
            [3, 2, 1, nil, nil])
    }

    func testOrderByCollation() throws {
        try assertFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value) },
            ["C", "D", "a", "b"])

        try assertFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value, collation: .binary) },
            ["C", "D", "a", "b"])
    }

    func testOrderByDefaultCollation() throws {
        db = Database(path: ":memory:", .collection(RowT<String>.self, .column(\.value, collation: .caseInsensitive)))

        try assertFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value) },
            ["a", "b", "C", "D"])

        try assertFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy("\(\.value)") },
            ["a", "b", "C", "D"])

        // default collation can be overridden
        try assertFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value, collation: .binary) },
            ["C", "D", "a", "b"])
    }

    func testOrderByUnicodeCompare() throws {
        try assertFilter(
            ["z", "Z", "u", "ü"],
            { $0.all().orderBy(\.value) },
            ["Z", "u", "z", "ü"])

        try assertFilter(
            ["z", "Z", "u", "ü"],
            { $0.all().orderBy(\.value, collation: .string) },
            ["Z", "u", "z", "ü"])
    }

    func testOrderByCustomCollation() throws {
        try assertFilter(
            ["x", "me first!", "a"],
            { $0.all().orderBy(\.value) },
            ["a", "me first!", "x"])

        try assertFilter(
            ["x", "me first!", "a"],
            { $0.all().orderBy(\.value, collation: .stringMeFirstAlwaysGoesFirst) },
            ["me first!", "a", "x"])
    }
}

extension Collation {
    static let stringMeFirstAlwaysGoesFirst = Collation("stringMeFirstAlwaysGoesFirst") { (a, b) in
        if a == b {
            return .orderedSame
        }
        if a == "me first!" {
            return .orderedAscending
        }
        if b == "me first!" {
            return .orderedDescending
        }
        return a < b ? .orderedAscending : .orderedDescending
    }
}
