import Testing
@testable import AD_BYPASSER

struct ValidatorsTests {
    @Test func usernameAcceptsAlphanumeric() {
        #expect(Validators.username("alice99") == nil)
        #expect(Validators.username("ABC") == nil)
    }

    @Test func usernameRejectsTooShortTooLongAndSymbols() {
        #expect(Validators.username("ab") != nil)
        #expect(Validators.username(String(repeating: "a", count: 21)) != nil)
        #expect(Validators.username("alice!") != nil)
    }

    @Test func passwordRequiresLetterDigitSymbol() {
        #expect(Validators.password("aaaaaaaa") != nil)        // missing digit/symbol
        #expect(Validators.password("aaaaaaa1") != nil)        // missing symbol
        #expect(Validators.password("aaa11!") != nil)          // too short
        #expect(Validators.password("alice123!") == nil)
    }

    @Test func emailIsOptionalButValidatesWhenPresent() {
        #expect(Validators.email("") == nil)
        #expect(Validators.email("ok@ex.com") == nil)
        #expect(Validators.email("not-an-email") != nil)
    }
}
