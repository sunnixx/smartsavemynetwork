import XCTest
@testable import SmartSave

final class CardTextParserTests: XCTestCase {

    func test_parsesEmail() {
        let lines = ["John Smith", "Engineer", "Acme Corp", "john@acme.com", "+1 555-123-4567"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.emails, ["john@acme.com"])
    }

    func test_parsesMultipleEmails() {
        let lines = ["Jane Doe", "CEO", "Beta Inc", "jane@beta.io", "info@beta.io", "(415) 222-3333"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.emails, ["jane@beta.io", "info@beta.io"])
        XCTAssertEqual(result.email, "jane@beta.io\ninfo@beta.io")
    }

    func test_parsesPhone() {
        let lines = ["Jane Doe", "CEO", "Beta Inc", "jane@beta.io", "(415) 222-3333"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.phones, ["(415) 222-3333"])
    }

    func test_parsesMultiplePhones() {
        let lines = ["Tom Hardy", "VP Sales", "MegaCorp", "tom@mega.com", "+1 555-123-4567", "800-555-0001"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.phones, ["+1 555-123-4567", "800-555-0001"])
        XCTAssertEqual(result.phone, "+1 555-123-4567\n800-555-0001")
    }

    func test_parsesName_asFirstLine() {
        let lines = ["Sarah Connor", "Director", "Cyberdyne", "sarah@cyberdyne.com"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.name, "Sarah Connor")
    }

    func test_parsesCompanyAndTitle_fromRemainingLines() {
        let lines = ["Tom Hardy", "VP Sales", "MegaCorp", "tom@mega.com", "800-555-0001"]
        let result = CardTextParser.parse(lines)
        XCTAssertEqual(result.title, "VP Sales")
        XCTAssertEqual(result.company, "MegaCorp")
    }

    func test_handlesEmptyInput() {
        let result = CardTextParser.parse([])
        XCTAssertNil(result.email)
        XCTAssertNil(result.phone)
        XCTAssertNil(result.name)
    }
}
