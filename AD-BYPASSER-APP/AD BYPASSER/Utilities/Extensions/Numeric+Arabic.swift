import Foundation

private let arabicFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "ar")
    f.numberStyle = .decimal
    return f
}()

extension Int {
    var arabic: String { arabicFormatter.string(from: NSNumber(value: self)) ?? "\(self)" }
}

extension Double {
    var arabicPercent: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ar")
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: self)) ?? "\(Int(self * 100))%"
    }
}
