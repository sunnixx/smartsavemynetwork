import XCTest
import UserNotifications
@testable import SmartSave

final class NotificationServiceTests: XCTestCase {

    func test_buildRequest_hasCorrectIdentifier() {
        let contactID = UUID()
        let date = Date().addingTimeInterval(3600)
        let request = NotificationService.buildRequest(contactID: contactID, contactName: "Alice", date: date)
        XCTAssertEqual(request.identifier, contactID.uuidString)
    }

    func test_buildRequest_titleContainsContactName() {
        let contactID = UUID()
        let date = Date().addingTimeInterval(3600)
        let request = NotificationService.buildRequest(contactID: contactID, contactName: "Bob", date: date)
        let content = request.content
        XCTAssertTrue(content.title.contains("Bob"))
    }
}
