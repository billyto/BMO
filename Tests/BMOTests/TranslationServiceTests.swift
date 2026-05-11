import XCTest
@testable import BMOLib

final class TranslationServiceTests: XCTestCase {

    var sut: TranslationService!
    var mockNetworkClient: MockNetworkClient!

    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        sut = TranslationService(networkClient: mockNetworkClient)
    }

    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
        super.tearDown()
    }

    // MARK: - API Key Validation Tests

    func testInitializationWithValidAPIKey() throws {
        let service = try TranslationService(apiKey: "valid-key-123", networkClient: mockNetworkClient)
        XCTAssertNotNil(service)
    }

    func testInitializationWithEmptyAPIKeyThrows() {
        XCTAssertThrowsError(try TranslationService(apiKey: "", networkClient: mockNetworkClient))
    }

    // MARK: - Translation Success Tests

    func testTranslateDanishToEnglishSuccess() async throws {
        // Given
        let danishText = "Hej verden"
        let expectedTranslation = "Hello world"
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: expectedTranslation, detectedSourceLanguage: "DA")]
        )

        // When
        let result = try await sut.translate(text: danishText, from: .danish, to: .english)

        // Then
        XCTAssertEqual(result, expectedTranslation)
        XCTAssertEqual(mockNetworkClient.lastRequestURL?.absoluteString, "https://api-free.deepl.com/v2/translate")
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["text"], danishText)
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["source_lang"], "DA")
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["target_lang"], "EN")
    }

    func testTranslateEnglishToDanishSuccess() async throws {
        // Given
        let englishText = "Hello world"
        let expectedTranslation = "Hej verden"
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: expectedTranslation, detectedSourceLanguage: "EN")]
        )

        // When
        let result = try await sut.translate(text: englishText, from: .english, to: .danish)

        // Then
        XCTAssertEqual(result, expectedTranslation)
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["source_lang"], "EN")
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["target_lang"], "DA")
    }

    func testTranslateWithSpecialCharacters() async throws {
        // Given
        let textWithSpecialChars = "Hvad hedder du? Jeg hedder Søren! 😊"
        let expectedTranslation = "What is your name? My name is Søren! 😊"
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: expectedTranslation, detectedSourceLanguage: "DA")]
        )

        // When
        let result = try await sut.translate(text: textWithSpecialChars, from: .danish, to: .english)

        // Then
        XCTAssertEqual(result, expectedTranslation)
    }

    func testTranslateLongText() async throws {
        // Given
        let longText = String(repeating: "Dette er en lang tekst. ", count: 100)
        let expectedTranslation = String(repeating: "This is a long text. ", count: 100)
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: expectedTranslation, detectedSourceLanguage: "DA")]
        )

        // When
        let result = try await sut.translate(text: longText, from: .danish, to: .english)

        // Then
        XCTAssertEqual(result, expectedTranslation)
    }

    // MARK: - Error Handling Tests

    func testTranslateEmptyTextThrows() async {
        // When/Then
        do {
            _ = try await sut.translate(text: "", from: .danish, to: .english)
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.emptyText)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateWithNetworkErrorThrows() async {
        // Given
        mockNetworkClient.shouldThrowError = true
        mockNetworkClient.errorToThrow = URLError(.notConnectedToInternet)

        // When/Then
        do {
            _ = try await sut.translate(text: "Hej", from: .danish, to: .english)
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateWithInvalidAPIKeyThrows() async {
        // Given
        mockNetworkClient.shouldThrowError = true
        mockNetworkClient.errorToThrow = TranslationError.invalidAPIKey

        // When/Then
        do {
            _ = try await sut.translate(text: "Hej", from: .danish, to: .english)
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.invalidAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateWithQuotaExceededThrows() async {
        // Given
        mockNetworkClient.shouldThrowError = true
        mockNetworkClient.errorToThrow = TranslationError.quotaExceeded

        // When/Then
        do {
            _ = try await sut.translate(text: "Hej", from: .danish, to: .english)
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.quotaExceeded)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateWithInvalidJSONResponseThrows() async {
        // Given
        mockNetworkClient.mockInvalidJSON = true

        // When/Then
        do {
            _ = try await sut.translate(text: "Hej", from: .danish, to: .english)
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            XCTAssertEqual(error, TranslationError.invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Authentication Tests

    func testAPIKeyIncludedInRequestHeader() async throws {
        // Given
        let apiKey = "test-api-key-123"
        let service = try TranslationService(apiKey: apiKey, networkClient: mockNetworkClient)
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: "Hello", detectedSourceLanguage: "DA")]
        )

        // When
        _ = try await service.translate(text: "Hej", from: .danish, to: .english)

        // Then
        XCTAssertEqual(mockNetworkClient.lastRequestHeaders?["Authorization"], "DeepL-Auth-Key \(apiKey)")
    }

    // MARK: - Auto-detect Translation Tests

    func testTranslateWithNilSourceOmitsSourceLang() async throws {
        // Given
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: "Hello", detectedSourceLanguage: "DA")]
        )

        // When
        let result = try await sut.translate(text: "Hej", targetLanguage: .english, sourceLanguage: nil)

        // Then
        XCTAssertEqual(result.text, "Hello")
        XCTAssertEqual(result.detectedSource, .danish)
        XCTAssertNil(mockNetworkClient.lastRequestBody?["source_lang"],
                     "source_lang must be omitted so DeepL can auto-detect")
        XCTAssertEqual(mockNetworkClient.lastRequestBody?["target_lang"], "EN")
    }

    func testTranslateWithUnknownDetectedSourceReturnsNil() async throws {
        // DeepL detected something we don't have a Language case for (e.g. French)
        mockNetworkClient.mockResponse = DeepLResponse(
            translations: [Translation(text: "Hello", detectedSourceLanguage: "FR")]
        )

        let result = try await sut.translate(text: "Bonjour", targetLanguage: .english)

        XCTAssertEqual(result.text, "Hello")
        XCTAssertNil(result.detectedSource, "Unrecognized DeepL source codes should surface as nil")
    }

    func testAutoTranslateWithDanishSourceMakesSingleCall() async throws {
        // Given — first (only) call returns the DA→EN translation
        mockNetworkClient.mockResponseQueue = [
            DeepLResponse(translations: [Translation(text: "Hello world", detectedSourceLanguage: "DA")])
        ]

        // When
        let result = try await sut.autoTranslate(text: "Hej verden")

        // Then
        XCTAssertEqual(result.translated, "Hello world")
        XCTAssertEqual(result.detectedSource, .danish)
        XCTAssertEqual(mockNetworkClient.recordedBodies.count, 1,
                       "Danish input should only need one call")
        XCTAssertEqual(mockNetworkClient.recordedBodies[0]["target_lang"], "EN")
        XCTAssertNil(mockNetworkClient.recordedBodies[0]["source_lang"])
    }

    func testAutoTranslateWithEnglishSourceMakesTwoCalls() async throws {
        // Given — first call detects EN (target was EN, so result is useless);
        // autoTranslate must then issue a second call targeting DA.
        mockNetworkClient.mockResponseQueue = [
            DeepLResponse(translations: [Translation(text: "Hello world", detectedSourceLanguage: "EN")]),
            DeepLResponse(translations: [Translation(text: "Hej verden", detectedSourceLanguage: "EN")])
        ]

        // When
        let result = try await sut.autoTranslate(text: "Hello world")

        // Then
        XCTAssertEqual(result.translated, "Hej verden",
                       "EN input should return the second call's DA result, not the EN→EN no-op")
        XCTAssertEqual(result.detectedSource, .english)
        XCTAssertEqual(mockNetworkClient.recordedBodies.count, 2)
        XCTAssertEqual(mockNetworkClient.recordedBodies[0]["target_lang"], "EN")
        XCTAssertNil(mockNetworkClient.recordedBodies[0]["source_lang"])
        XCTAssertEqual(mockNetworkClient.recordedBodies[1]["target_lang"], "DA")
        XCTAssertEqual(mockNetworkClient.recordedBodies[1]["source_lang"], "EN",
                       "Second call must pin source=EN to avoid a detection loop")
    }

    func testAutoTranslateWithOtherSourceKeepsEnglishResult() async throws {
        // DeepL detects French — we don't have a Language case for it, so the
        // English-targeted first result is the correct thing to return.
        mockNetworkClient.mockResponseQueue = [
            DeepLResponse(translations: [Translation(text: "Hello world", detectedSourceLanguage: "FR")])
        ]

        let result = try await sut.autoTranslate(text: "Bonjour le monde")

        XCTAssertEqual(result.translated, "Hello world")
        XCTAssertNil(result.detectedSource)
        XCTAssertEqual(mockNetworkClient.recordedBodies.count, 1,
                       "Non-DA/EN sources should not trigger the second call")
    }

    func testAutoTranslatePropagatesErrors() async {
        // Given — the first call throws a network error
        mockNetworkClient.shouldThrowError = true
        mockNetworkClient.errorToThrow = URLError(.notConnectedToInternet)

        // When/Then
        do {
            _ = try await sut.autoTranslate(text: "Hej")
            XCTFail("Expected error")
        } catch let error as TranslationError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Network Client

final class MockNetworkClient: NetworkClient, @unchecked Sendable {
    var mockResponse: DeepLResponse?
    /// For multi-call sequences (e.g. autoTranslate's two-call EN→DA path) —
    /// each call pops the next response. Falls back to `mockResponse` when empty.
    var mockResponseQueue: [DeepLResponse] = []
    var shouldThrowError = false
    var errorToThrow: Error?
    var mockInvalidJSON = false

    var lastRequestURL: URL?
    var lastRequestBody: [String: String]?
    var lastRequestHeaders: [String: String]?
    /// Every request body seen, in order — for asserting on multi-call flows.
    var recordedBodies: [[String: String]] = []

    func performRequest(url: URL, body: [String: String], headers: [String: String]) async throws -> DeepLResponse {
        lastRequestURL = url
        lastRequestBody = body
        lastRequestHeaders = headers
        recordedBodies.append(body)

        if shouldThrowError {
            throw errorToThrow ?? TranslationError.networkError
        }

        if mockInvalidJSON {
            throw TranslationError.invalidResponse
        }

        if !mockResponseQueue.isEmpty {
            return mockResponseQueue.removeFirst()
        }
        guard let response = mockResponse else {
            throw TranslationError.invalidResponse
        }

        return response
    }
}
