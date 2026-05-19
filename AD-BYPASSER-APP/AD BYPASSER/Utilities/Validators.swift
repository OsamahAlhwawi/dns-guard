import Foundation

enum Validators {
    static func username(_ value: String) -> String? {
        if value.count < 3 || value.count > 20 { return String(localized: "validation.username.length") }
        let alphanumeric = CharacterSet.alphanumerics
        if value.unicodeScalars.contains(where: { !alphanumeric.contains($0) }) {
            return String(localized: "validation.username.alphanumeric")
        }
        return nil
    }

    static func password(_ value: String) -> String? {
        if value.count < 8 { return String(localized: "validation.password.length") }
        let hasLetter = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = value.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        let symbols = CharacterSet.letters.union(.decimalDigits).inverted
        let hasSymbol = value.unicodeScalars.contains { symbols.contains($0) }
        if !hasLetter { return String(localized: "validation.password.letter") }
        if !hasDigit { return String(localized: "validation.password.digit") }
        if !hasSymbol { return String(localized: "validation.password.symbol") }
        return nil
    }

    static func email(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        if value.range(of: pattern, options: .regularExpression) == nil {
            return String(localized: "validation.email.format")
        }
        return nil
    }
}
