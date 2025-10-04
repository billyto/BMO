import XCTest
@testable import BMO

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
}

// MARK: - Mock Network Client

class MockNetworkClient: NetworkClient {
    var mockResponse: DeepLResponse?
    var shouldThrowError = false
    var errorToThrow: Error?
    var mockInvalidJSON = false

    var lastRequestURL: URL?
    var lastRequestBody: [String: String]?
    var lastRequestHeaders: [String: String]?

    func performRequest(url: URL, body: [String: String], headers: [String: String]) async throws -> DeepLResponse {
        lastRequestURL = url
        lastRequestBody = body
        lastRequestHeaders = headers

        if shouldThrowError {
            throw errorToThrow ?? TranslationError.networkError
        }

        if mockInvalidJSON {
            throw TranslationError.invalidResponse
        }

        guard let response = mockResponse else {
            throw TranslationError.invalidResponse
        }

        return response
    }
}
