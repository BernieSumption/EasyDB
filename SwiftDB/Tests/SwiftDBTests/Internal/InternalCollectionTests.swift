//
//  InternalCollectionTests.swift
//  
//
//  Created by Bernard Sumption on 29/03/2022.
//

import XCTest
@testable import SwiftDB

class InternalCollectionTests: SwiftDBTestCase {
    
    func testDefaultCollectionCollationUsedInSQL() throws {
        var sql = ""
        db = Database(path: ":memory:", logSQL: .custom({ sql = $0 + "\n" }),
                      .collection(Row.self,
                                  .column(\.value, .index())))
        let c = try db.collection(Row.self)
        
        // index created with default collation "string"
        XCTAssertTrue(sql.contains(#"CREATE INDEX "Row-value-string" ON "Row" ( "value" COLLATE "string" )"#))

        let _ = try c.filter(\.value, is: 4).orderBy(\.value).fetchMany()
        assertString(sql, contains: #"WHERE "value" COLLATE "string" IS"#)
        assertString(sql, contains: #"ORDER BY "value" COLLATE "string""#)
    }
    
    func testExplicitDefaultCollectionCollationUsedInSQL() throws {
        var sql = ""
        db = Database(path: ":memory:", logSQL: .custom({ sql = $0 + "\n" }),
                      .collection(Row.self,
                                  .column(\.value, collation: .binary, .index())))
        let c = try db.collection(Row.self)
        
        // index created with "binary" collation
        assertString(sql, contains:#"CREATE INDEX "Row-value-binary" ON "Row" ( "value" COLLATE "binary" )"#)

        
        // "binary" collation used in filter and order by
        let _ = try c.filter(\.value, is: 4).orderBy(\.value).fetchMany()
        assertString(sql, contains: #"WHERE "value" COLLATE "binary" IS"#)
        assertString(sql, contains: #"ORDER BY "value" COLLATE "binary""#)
    }
    
    func testOverrideCollationUsedInSQL() throws {
        var sql = ""
        db = Database(path: ":memory:", logSQL: .custom({ sql = $0 + "\n" }),
                      .collection(Row.self,
                                  .column(\.value, collation: .binary, .index(collation: .caseInsensitive))))
        let c = try db.collection(Row.self)
        
        // index created with "caseInsensitive" collation
        assertString(sql, contains:#"CREATE INDEX "Row-value-caseInsensitive" ON "Row" ( "value" COLLATE "caseInsensitive" )"#)

        
        // override collation used in filter and order by
        let _ = try c
            .filter(\.value, is: 4, collation: .string)
            .orderBy(\.value, collation: .localized)
            .fetchMany()
        assertString(sql, contains: #"WHERE "value" COLLATE "string" IS"#)
        assertString(sql, contains: #"ORDER BY "value" COLLATE "localized""#)
    }

}
