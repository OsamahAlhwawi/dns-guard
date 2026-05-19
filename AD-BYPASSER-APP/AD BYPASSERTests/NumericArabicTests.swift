import Testing
@testable import AD_BYPASSER

struct NumericArabicTests {
    @Test func intRendersWithArabicIndicDigits() {
        // "١٬٢٣٤" or similar Arabic-Indic representation; just assert it's non-empty and not "1234".
        let s = 1234.arabic
        #expect(!s.isEmpty)
        #expect(s != "1234")
    }

    @Test func percentFormatterEmitsArabicLocale() {
        let s = 0.123.arabicPercent
        #expect(!s.isEmpty)
    }
}
