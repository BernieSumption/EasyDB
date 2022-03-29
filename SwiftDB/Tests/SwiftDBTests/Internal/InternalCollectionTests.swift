//
//  InternalCollectionTests.swift
//  
//
//  Created by Bernard Sumption on 29/03/2022.
//

import XCTest
@testable import SwiftDB

class InternalCollectionTests: SwiftDBTestCase {

    func testExample() throws {
        var sql = ""
        db = Database(path: ":memory:", logSQL: .custom({ sql += $0 + "\n" }),
                      .collection(Row.self,
                                  .column(\.value, .index())))
        let c = try db.collection(Row.self)
        
        // index created with default collation "string"
        XCTAssertTrue(sql.contains(#"CREATE INDEX "Row-value-string" ON "Row" ( "value" COLLATE "string" )"#))

        sql = ""
        let _ = try c.filter(\.value, is: 4).fetchMany()
        assertString(sql, contains: #"WHERE "value" COLLATE "string""#)
        
        Next up: check order by, then 3 other kinds of test collation position
        
    }

}
