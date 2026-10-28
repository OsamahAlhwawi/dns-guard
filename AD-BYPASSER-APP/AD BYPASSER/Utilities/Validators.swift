import Foundation

enum Validators {
    static func username(_ value: String) -> String? {
        if value.count < 3 || value.count > 20 { return NSLocalizedString("validation.username.length", comment: "") }
        let alphanumeric = CharacterSet.alphanumerics
        if value.unicodeScalars.contains(where: { !alphanumeric.contains($0) }) {
            return NSLocalizedString("validation.username.alphanumeric", comment: "")
        }
        return nil
    }

    static func password(_ value: String) -> String? {
        if value.count < 8 { return NSLocalizedString("validation.password.length", comment: "") }
        let hasLetter = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = value.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        let symbols = CharacterSet.letters.union(.decimalDigits).inverted
        let hasSymbol = value.unicodeScalars.contains { symbols.contains($0) }
        if !hasLetter { return NSLocalizedString("validation.password.letter", comment: "") }
        if !hasDigit { return NSLocalizedString("validation.password.digit", comment: "") }
        if !hasSymbol { return NSLocalizedString("validation.password.symbol", comment: "") }
        return nil
    }

    static func email(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        if value.range(of: pattern, options: .regularExpression) == nil {
            return NSLocalizedString("validation.email.format", comment: "")
        }
        return nil
    }
}
