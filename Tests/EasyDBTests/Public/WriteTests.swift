import XCTest
import EasyDB

class WriteTests: EasyDBTestCase {

    func testInsert() throws {
        let c = try db.collection(KitchenSinkRecord.self)
        try c.insert(KitchenSinkRecord.standard)
        let row = try c.all().fetchOne()
        XCTAssertEqual(row, KitchenSinkRecord.standard)
    }

    func testBulkInsert() throws {
        let c = try db.collection(RowWithId.self)
        let rows = [RowWithId(), RowWithId()]
        try c.insert(rows)
        XCTAssertEqual(try c.all().fetchMany(), rows)
    }

    func testBulkInsertUsesTransaction() throws {
        let c = try db.collection(RowWithId.self)
        let a = RowWithId()
        let b = RowWithId()
        // should fail to insert the second `a`, so roll back and leave an empty collection
        assertErrorMessage(try c.insert([a, b, a]), contains: "UNIQUE constraint failed")
        XCTAssertEqual(try c.all().fetchMany(), [])
    }

    func testDelete() throws {
        let c = try db.collection(RowWithId.self)
        let r1 = RowWithId()
        let r2 = RowWithId()
        let r3 = RowWithId()
        let r4 = RowWithId()
        let r5 = RowWithId()
        try c.insert([r1, r2, r3, r4, r5])

        try c.filter(\.id, equalTo: r2.id).delete()
        XCTAssertEqual(try c.all().fetchMany(), [r1, r3, r4, r5])

        try c.filter(id: r4.id).delete()
        XCTAssertEqual(try c.all().fetchMany(), [r1, r3, r5])

        try c.all().delete()
        XCTAssertEqual(try c.all().fetchMany(), [])
    }

    func testUpsertOfIdentifiable() throws {
        let r1 = IdAndName(id: UUID(), name: "r1")
        let r2 = IdAndName(id: UUID(), name: "r2")
        let c = try db.collection(IdAndName.self)

        try c.insert([r1, r2])

        var r1v2 = r1
        r1v2.name = "r1-v2"
        try c.insert(r1v2, onConflict: .replace)
        XCTAssertEqual(try c.all().orderBy(\.name).fetchMany(), [r1v2, r2])

        var r1v3 = r1v2
        r1v3.name = "r1-v3"
        try c.insert(r1v3, onConflict: .ignore)
        XCTAssertEqual(try c.all().orderBy(\.name).fetchMany(), [r1v2, r2])

        assertErrorMessage(try c.insert(r1v3), contains: "UNIQUE constraint failed")
        assertErrorMessage(try c.insert(r1v3, onConflict: .abort), contains: "UNIQUE constraint failed")
    }

    struct IdAndName: Record, Equatable {
        var id: UUID
        var name: String
    }

    func testUpsertOfUnique() throws {
        db = EasyDB(.memory)
        let r1 = HandleAndName(handle: "a", name: "r1")
        let r2 = HandleAndName(handle: "b", name: "r2")
        let c = try db.collection(HandleAndName.self)

        try c.insert([r1, r2])

        var r1v2 = r1
        r1v2.name = "r1-v2"
        try c.insert(r1v2, onConflict: .replace)
        XCTAssertEqual(try c.all().orderBy(\.name).fetchMany(), [r1v2, r2])

        var r1v3 = r1v2
        r1v3.name = "r1-v3"
        try c.insert(r1v3, onConflict: .ignore)
        XCTAssertEqual(try c.all().orderBy(\.name).fetchMany(), [r1v2, r2])

        assertErrorMessage(try c.insert(r1v3), contains: "UNIQUE constraint failed")
        assertErrorMessage(try c.insert(r1v3, onConflict: .abort), contains: "UNIQUE constraint failed")
    }

    struct HandleAndName: Record, Equatable {
        var id = UUID()
        @Unique var handle: String
        var name: String
    }

    func testUpdate() throws {
        let c = try db.collection(Row.self)

        try c.insert([Row(1), Row(2), Row(3)])

        try c.filter(\.value, equalTo: 2).update(\.value, 0)

        XCTAssertEqual(try c.all().fetchMany().map(\.value), [1, 0, 3])
    }

    func testMultipleUpdate() throws {
        let c = try db.collection(MultipleUpdate.self)

        let ra = MultipleUpdate(a: "a", b: 0)
        let rb = MultipleUpdate(a: "b", b: 1)
        let rc = MultipleUpdate(a: "c", b: 2)

        try c.insert([ra, rb, rc])

        try c
            .filter(\.a, lessThan: "c")
            .updating(\.a, "new")
            .updating(\.b, 10)
            .update()

        XCTAssertEqual(
            try c.all().fetchMany(),
            [
                MultipleUpdate(id: ra.id, a: "new", b: 10),
                MultipleUpdate(id: rb.id, a: "new", b: 10),
                MultipleUpdate(id: rc.id, a: "c", b: 2)
            ])
    }
    struct MultipleUpdate: Record, Equatable {
        var id = UUID()
        let a: String
        let b: Int
    }

    func testUpdateWithOrderAndLimit() throws {
        let c = try db.collection(Row.self)

        try c.insert([Row(1), Row(2), Row(3)])

        try c.all().orderBy(\.value, .descending).limit(1).update(\.value, 0)

        XCTAssertEqual(try c.all().fetchMany().map(\.value), [1, 2, 0])
    }

    func testUpdateWithCustomSQL() throws {
        let c = try db.collection(Row.self)

        try c.insert([Row(1), Row(2), Row(3)])

        try c.all().orderBy(\.value, .descending).limit(1).update(\.value, 0)

        XCTAssertEqual(try c.all().fetchMany().map(\.value), [1, 2, 0])

        try assertModification(
            ["a", "b", "c"],
            { try $0.all().update("\(\.value) = \(\.value) || '-updated'") },
            ["a-updated", "b-updated", "c-updated"])
    }
}
