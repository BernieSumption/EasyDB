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
            { $0.all().orderBy(\.value, collate: .asciiCaseInsensitive) },
            ["a", "b", "C", "D"])
    }
}

