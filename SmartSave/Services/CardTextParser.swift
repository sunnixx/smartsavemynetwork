import Foundation

struct ParsedCard {
    var name: String?
    var title: String?
    var company: String?
    var email: String?
    var phone: String?
}

struct CardTextParser {
    static func parse(_ lines: [String]) -> ParsedCard {
        var result = ParsedCard()
        var remaining: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isEmail(trimmed) {
                result.email = trimmed
            } else if isPhone(trimmed) {
                result.phone = trimmed
            } else {
                remaining.append(trimmed)
            }
        }

        if !remaining.isEmpty { result.name = remaining[0] }
        if remaining.count > 1  { result.title = remaining[1] }
        if remaining.count > 2  { result.company = remaining[2] }

        return result
    }

    private static func isEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isPhone(_ s: String) -> Bool {
        let digits = s.filter { $0.isNumber }
        let pattern = #"[\d\s\(\)\-\+\.]{7,}"#
        return digits.count >= 7 && s.range(of: pattern, options: .regularExpression) != nil
    }
}
