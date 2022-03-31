import XCTest
import SwiftDB

class FilterTests: SwiftDBTestCase {
    
    func testEquals() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, equalTo: 3) },
            [3])
    }
    
    func testNoResults() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, equalTo: 20) },
            [])
    }
    
    func testEqualsWithArrayValue() throws {
        try assertFilter(
            [[1, 2], [2, 2], [3, 1]],
            { $0.filter(\.value, equalTo: [2, 2]) },
            [[2, 2]])
    }
    
    func testEqualsWithStructValue() throws {
        let a = Struct(foo: "a")
        let b = Struct(foo: "b")
        try assertFilter(
            [a, b],
            { $0.filter(\.value, equalTo: b) },
            [b])
    }
    
    func testNotEquals() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, notEqualTo: 3) },
            [1, 2, 4, 5])
    }

    func testLessThan() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThan: 3) },
            [1, 2])
    }

    func testLessThanOrEqualTo() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThanOrEqualTo: 3) },
            [1, 2, 3])
    }

    func testGreaterThan() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, greaterThan: 3) },
            [4, 5])
    }

    func testGreaterThanOrEqualTo() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, greaterThanOrEqualTo: 3) },
            [3, 4, 5])
    }

    func testFilterChaining() throws {
        try assertFilter(
            [1, 2, 3, 4, 5],
            { $0.filter(\.value, lessThan: 4).filter(\.value, greaterThan: 1) },
            [2, 3])
    }
    
    func testIsNull() throws {
        try assertFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, isNull: true) },
            [nil, nil])
        
        try assertFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, equalTo: nil) },
            [nil, nil])
    }

    func testIsNotNull() throws {
        try assertFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, isNull: false) },
            [1, 3, 5])
        
        try assertFilter(
            [1, nil, 3, nil, 5],
            { $0.filter(\.value, notEqualTo: nil) },
            [1, 3, 5])
    }

    func testLike() throws {
        try assertFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { $0.filter(\.value, like: "foo%") },
            ["foo", "food", "FOO"])
    }
    
    func testNotLike() throws {
        try assertFilter(
            ["foo", "food", "shizfoo", "FOO"],
            { $0.filter(\.value, notLike: "foo%") },
            ["shizfoo"])
    }
    
    func testSQLFilter() throws {
        let search = "'"
        let replace = ""
        let match = "ab"
        try assertFilter(
            ["a'b", "a'c", "'a'b'"],
            { $0.filter("replace(\(\.value), \(search), \(replace)) = \(match)") },
            ["a'b", "'a'b'"])
    }
    
    func testErrorMessage() throws {
        let c = try db.collection(RowT<Struct>.self)
        assertErrorMessage(
            try c.filter(\.value.foo, equalTo: "foo").fetchMany(),
            contains: #"querying by nested KeyPaths (\.value.foo) is not implemented"#)
    }
    
    func testFiltersWithCollation() throws {
        try assertFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, equalTo: "æ") },
            ["æ"])
        
        try assertFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, equalTo: "æ", collation: .caseInsensitive) },
            ["æ", "Æ"])
        
        try assertFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, greaterThanOrEqualTo: "æ") },
            ["æ"])
        
        try assertFilter(
            ["æ", "Æ"],
            { $0.filter(\.value, greaterThanOrEqualTo: "æ", collation: .caseInsensitive) },
            ["æ", "Æ"])
    }
    
    func testFilterCount() throws {
        let c = try populateCollectionOfRowT([1, 2, 3, 4, 5])
        
        XCTAssertEqual(
            try c.filter(\.value, greaterThanOrEqualTo: 3).fetchCount(),
            3)
        
        XCTAssertEqual(
            try c.all().fetchCount(),
            5)
    }
    
    func testSelectOneByProperty() throws {
        let c = try populateCollectionOfRowT([1, 2, 3, 4, 5])
        
        XCTAssertEqual(
            try c.all().fetchOne(\.value),
            1)
    }
    
    func testSelectManyByProperty() throws {
        let c = try populateCollectionOfRowT([1, 2, 3, 4, 5])
        
        XCTAssertEqual(
            try c.all().fetchMany(\.value),
            [1, 2, 3, 4, 5])
    }
}

extension FilterTests {
    
    struct Struct: Codable, Equatable {
        let foo: String
    }
}
