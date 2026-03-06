import XCTest
import CoreData
@testable import SmartSave

final class PersistenceControllerTests: XCTestCase {
    var sut: PersistenceController!

    override func setUp() {
        super.setUp()
        sut = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_createContact_setsIdAndCreatedAt() {
        let contact = sut.createContact(name: "Jane Doe")
        XCTAssertNotNil(contact.id)
        XCTAssertNotNil(contact.createdAt)
        XCTAssertEqual(contact.name, "Jane Doe")
    }

    func test_allContacts_returnsAllWhenNoSearch() {
        _ = sut.createContact(name: "Alice")
        _ = sut.createContact(name: "Bob")
        XCTAssertEqual(sut.allContacts().count, 2)
    }

    func test_allContacts_filtersBySearchText() {
        _ = sut.createContact(name: "Alice Smith")
        _ = sut.createContact(name: "Bob Jones")
        let results = sut.allContacts(searchText: "alice")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Alice Smith")
    }

    func test_delete_removesContact() {
        let contact = sut.createContact(name: "Delete Me")
        sut.delete(contact)
        XCTAssertEqual(sut.allContacts().count, 0)
    }
}
