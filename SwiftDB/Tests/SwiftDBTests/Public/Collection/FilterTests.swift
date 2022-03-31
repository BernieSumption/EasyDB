import XCTest
import SwiftDB

class FilterTests: SwiftDBTestCase {
    
    func testEquals() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, equalTo: 3) },
            [3])
    }
    
    func testNoResults() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, equalTo: 20) },
            [])
    }
    
    func testEqualsWithArrayValue() throws {
        try testFilter(
            [[1, 2], [2, 2], [3, 1]],
            { $0.filter(\.value, equalTo: [2, 2]) },
            [[2, 2]])
    }
    
    func testEqualsWithStructValue() throws {
        let a = Struct(foo: "a")
        let b = Struct(foo: "b")
        try testFilter(
            [a, b],
            { $0.filter(\.value, equalTo: b) },
            [b])
    }
    
    func testNotEquals() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, notEqualTo: 3) },
            [1, 2, 4, 5])
    }

    func testLessThan() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThan: 3) },
            [1, 2])
    }

    func testLessThanOrEqualTo() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThanOrEqualTo: 3) },
            [1, 2, 3])
    }

    func testGreaterThan() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, greaterThan: 3) },
            [4, 5])
    }

    func testGreaterThanOrEqualTo() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, greaterThanOrEqualTo: 3) },
            [3, 4, 5])
    }

    func testFilterChaining() throws {
        try testFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThan: 4).filter(\.value, greaterThan: 1) },
            [2, 3])
    }
    
    func testIsNull() throws {
        try testFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, isNull: true) },
            [nil, nil])
        
        try testFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, equalTo: nil) },
            [nil, nil])
    }

    func testIsNotNull() throws {
        try testFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, isNull: false) },
            [1, 3, 5])
        
        try testFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, notEqualTo: nil) },
            [1, 3, 5])
    }

    func testLike() throws {
        try testFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { $0.filter(\.value, like: "foo%") },
            ["foo", "food", "FOO"])
    }
    
    func testNotLike() throws {
        try testFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { $0.filter(\.value, notLike: "foo%") },
            ["shizfoo"])
    }
    
    func testSQLFilter() throws {
        let search = "'"
        let replace = ""
        let match = "ab"
        try testFilter(
            ["a'b", "a'c", "'a'b'"],
            { $0.filter("replace(\(\.value), \(search), \(replace)) = \(match)") },
            ["a'b", "'a'b'"])
    }
    
    func testErrorMessage() throws {
        let c = try db.collection(RowT<Struct>.self)
        assertErrorMessage(
            try c.filter(\.value.foo, equalTo: "foo").fetchMany(),
            contains: #"filtering by nested KeyPaths (\.value.foo) is not implemented"#)
    }
    
    func testFiltersWithCollation() throws {
        try testFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, equalTo: "æ") },
            ["æ"])
        
        try testFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, equalTo: "æ", collation: .caseInsensitive) },
            ["æ", "Æ"])
        
        try testFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, greaterThanOrEqualTo: "æ") },
            ["æ"])
        
        try testFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, greaterThanOrEqualTo: "æ", collation: .caseInsensitive) },
            ["æ", "Æ"])
    }
    
    func testFilterCount() throws {
        try testQuery(
            [1, 2, 3, 4, 5],
            { try $0.filter(\.value, greaterThanOrEqualTo: 3).fetchCount() },
            3)
        
        try testQuery(
            [1, 2, 3, 4, 5],
            { try $0.all().fetchCount() },
            5)
    }
}

extension FilterTests {
    
    struct Struct: Codable, Equatable {
        let foo: String
    }
}
