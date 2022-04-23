import XCTest
@testable import EasyDB

class InternalCollectionTests: EasyDBTestCase {

    func testDefaultCollectionCollationUsedInSQL() throws {
        var sql = ""
        db = EasyDB(.memory)
        db.logSQL = .custom({ sql = $0 + "\n" })

        let c = try db.collection(DefaultCollectionCollationUsedInSQL.self)

        // index created with default collation "string"
        assertString(sql, contains: "`value` COLLATE `string`")

        _ = try c.filter(\.value, equalTo: 4).orderBy(\.value).fetchMany()
        assertString(sql, contains: "WHERE `value` COLLATE `string` IS")
        assertString(sql, contains: "ORDER BY `value` COLLATE `string`")
    }

    struct DefaultCollectionCollationUsedInSQL: Record {
        var id = UUID()
        @Index var value: Int
    }

    func testExplicitDefaultCollectionCollationUsedInSQL() throws {
        var sql = ""
        db = EasyDB(.memory)
        db.logSQL = .custom({ sql = $0 + "\n" })

        let c = try db.collection(ExplicitDefaultCollectionCollationUsedInSQL.self)

        // index created with "binary" collation
        assertString(sql, contains: "`value` COLLATE `binary`")

        // "binary" collation used in filter and order by
        _ = try c.filter(\.value, equalTo: 4).orderBy(\.value).fetchMany()
        assertString(sql, contains: "WHERE `value` COLLATE `binary` IS")
        assertString(sql, contains: "ORDER BY `value` COLLATE `binary`")
    }

    struct ExplicitDefaultCollectionCollationUsedInSQL: Record {
        var id = UUID()
        @CollateBinary @Index var value: Int
    }

    func testOverrideCollationUsedInSQL() throws {
        var sql = ""
        db = EasyDB(.memory)
        db.logSQL = .custom({ sql = $0 + "\n" })
        let c = try db.collection(OverrideCollationUsedInSQL.self)

        // override collation used in filter and order by
        _ = try c
            .filter(\.value, equalTo: 4, collation: .string)
            .orderBy(\.value, collation: .localized)
            .fetchMany()
        assertString(sql, contains: "WHERE `value` COLLATE `string` IS")
        assertString(sql, contains: "ORDER BY `value` COLLATE `localized`")
    }

    struct OverrideCollationUsedInSQL: Record {
        var id = UUID()
        @CollateBinary @Index var value: Int
    }

}
