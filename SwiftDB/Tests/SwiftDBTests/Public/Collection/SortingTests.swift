import XCTest
import SwiftDB

class SortingTests: SwiftDBTestCase {
    
    func testOrderBy() throws {
        try testFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value) },
            [1, 2, 3])
    }
    
    func testOrderByDirection() throws {
        try testFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value, .ascending) },
            [1, 2, 3])
        
        try testFilter(
            [3, 1, 2],
            { $0.all().orderBy(\.value, .descending) },
            [3, 2, 1])
    }
    
    func testOrderByNulls() throws {
        try testFilter(
            [1, nil, 2, nil, 3],
            { $0.all().orderBy(\.value, .descending, nulls: .first) },
            [nil, nil, 3, 2, 1])
        
        try testFilter(
            [1, nil, 2, nil, 3],
            { $0.all().orderBy(\.value, .descending, nulls: .last) },
            [3, 2, 1, nil, nil])
    }
    
    func testOrderByCollation() throws {
        try testFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value) },
            ["C", "D", "a", "b"])
        
        try testFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value, collate: .binary) },
            ["C", "D", "a", "b"])
        
        try testFilter(
            ["a", "b", "C", "D"],
            { $0.all().orderBy(\.value, collate: .caseInsensitive) },
            ["a", "b", "C", "D"])
    }
    
    func testOrderByUnicodeCompare() throws {
        try testFilter(
            ["z", "Z", "u", "ü"],
            { $0.all().orderBy(\.value) },
            ["Z", "u", "z", "ü"])
        
        try testFilter(
            ["z", "Z", "u", "ü"],
            { $0.all().orderBy(\.value, collate: .string) },
            ["Z", "u", "z", "ü"])
    }
    
    func testOrderByCustomCollation() throws {
        
        try testFilter(
            ["x", "me first!", "a"],
            { $0.all().orderBy(\.value) },
            ["a", "me first!", "x"])
        
        try testFilter(
            ["x", "me first!", "a"],
            { $0.all().orderBy(\.value, collate: .stringMeFirstAlwaysGoesFirst) },
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

