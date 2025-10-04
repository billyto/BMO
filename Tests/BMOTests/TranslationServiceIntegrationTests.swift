import XCTest
@testable import BMO

/// Integration tests that call the real DeepL API
/// These tests are disabled by default to avoid using API quota during regular test runs
/// To run these tests:
/// 1. Set the DEEPL_API_KEY environment variable
/// 2. Set ENABLE_INTEGRATION_TESTS=1 environment variable
/// 3. Run: DEEPL_API_KEY=your-key ENABLE_INTEGRATION_TESTS=1 swift test
final class TranslationServiceIntegrationTests: XCTestCase {

    var sut: TranslationService!
    var networkClient: URLSessionNetworkClient!

    override func setUp() {
        super.setUp()

        // Skip tests if integration tests are not enabled
        guard ProcessInfo.processInfo.environment["ENABLE_INTEGRATION_TESTS"] == "1" else {
            return
        }

        networkClient = URLSessionNetworkClient()
    }

    override func tearDown() {
        sut = nil
        networkClient = nil
        super.tearDown()
    }

    // MARK: - Integration Tests

    func testRealTranslationDanishToEnglish() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENABLE_INTEGRATION_TESTS"] == "1",
            "Integration tests disabled. Set ENABLE_INTEGRATION_TESTS=1 to run."
        )

        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            XCTFail("DEEPL_API_KEY environment variable not set")
            return
        }

        // Given
        sut = try TranslationService(apiKey: apiKey, networkClient: networkClient)
        let danishText = "Hej verden"

        // When
        let result = try await sut.translate(text: danishText, from: .danish, to: .english)

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("hello") || result.lowercased().contains("world"))
        print("✅ Translation: '\(danishText)' -> '\(result)'")
    }

    func testRealTranslationEnglishToDanish() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENABLE_INTEGRATION_TESTS"] == "1",
            "Integration tests disabled. Set ENABLE_INTEGRATION_TESTS=1 to run."
        )

        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            XCTFail("DEEPL_API_KEY environment variable not set")
            return
        }

        // Given
        sut = try TranslationService(apiKey: apiKey, networkClient: networkClient)
        let englishText = "Hello world"

        // When
        let result = try await sut.translate(text: englishText, from: .english, to: .danish)

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("hej") || result.lowercased().contains("verden"))
        print("✅ Translation: '\(englishText)' -> '\(result)'")
    }

    func testRealTranslationWithComplexSentence() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENABLE_INTEGRATION_TESTS"] == "1",
            "Integration tests disabled. Set ENABLE_INTEGRATION_TESTS=1 to run."
        )

        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            XCTFail("DEEPL_API_KEY environment variable not set")
            return
        }

        // Given
        sut = try TranslationService(apiKey: apiKey, networkClient: networkClient)
        let danishText = "Jeg lærer dansk, fordi jeg elsker sproget."

        // When
        let result = try await sut.translate(text: danishText, from: .danish, to: .english)

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("learning") || result.lowercased().contains("language"))
        print("✅ Translation: '\(danishText)' -> '\(result)'")
    }

    func testRealAPIWithInvalidKey() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENABLE_INTEGRATION_TESTS"] == "1",
            "Integration tests disabled. Set ENABLE_INTEGRATION_TESTS=1 to run."
        )

        // Given
        sut = try TranslationService(apiKey: "invalid-key-12345", networkClient: networkClient)

        // When/Then
        do {
            _ = try await sut.translate(text: "Hej", from: .danish, to: .english)
            XCTFail("Expected invalidAPIKey error")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.invalidAPIKey)
            print("✅ Invalid API key correctly rejected")
        }
    }
}
