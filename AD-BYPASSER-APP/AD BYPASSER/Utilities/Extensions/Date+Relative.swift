import Foundation

extension Date {
    /// Arabic-localized relative formatter (e.g., "قبل دقيقتين").
    static let arabicRelativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar")
        f.unitsStyle = .full
        return f
    }()

    func relativeArabic(from reference: Date = .now) -> String {
        Self.arabicRelativeFormatter.localizedString(for: self, relativeTo: reference)
    }
}
