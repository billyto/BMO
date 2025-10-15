import Foundation

// MARK: - Language Enum

enum Language: String {
    case danish = "DA"
    case english = "EN"
}

// MARK: - Translation Error

enum TranslationError: Error, Equatable {
    case emptyText
    case invalidAPIKey
    case networkError
    case quotaExceeded
    case invalidResponse
}

// MARK: - DeepL Models

struct DeepLResponse: Codable {
    let translations: [Translation]
}

struct Translation: Codable {
    let text: String
    let detectedSourceLanguage: String

    enum CodingKeys: String, CodingKey {
        case text
        case detectedSourceLanguage = "detected_source_language"
    }
}

// MARK: - Network Client Protocol

protocol NetworkClient: Sendable {
    func performRequest(url: URL, body: [String: String], headers: [String: String]) async throws -> DeepLResponse
}

// MARK: - Translation Service

final class TranslationService: Sendable {
    private let apiKey: String
    private let networkClient: NetworkClient
    private let baseURL: String

    init(apiKey: String = "", networkClient: NetworkClient, configuration: APIConfiguration = .deepL) throws {
        guard !apiKey.isEmpty else {
            throw TranslationError.invalidAPIKey
        }
        self.apiKey = apiKey
        self.networkClient = networkClient
        self.baseURL = configuration.baseURL
    }

    convenience init(networkClient: NetworkClient) {
        // For testing purposes, uses a default test API key
        try! self.init(apiKey: "test-api-key", networkClient: networkClient)
    }

    func translate(text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> String {
        guard !text.isEmpty else {
            throw TranslationError.emptyText
        }

        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidResponse
        }

        let body: [String: String] = [
            "text": text,
            "source_lang": sourceLanguage.rawValue,
            "target_lang": targetLanguage.rawValue
        ]

        let headers: [String: String] = [
            "Authorization": "DeepL-Auth-Key \(apiKey)"
        ]

        do {
            let response = try await networkClient.performRequest(url: url, body: body, headers: headers)
            guard let translatedText = response.translations.first?.text else {
                throw TranslationError.invalidResponse
            }
            return translatedText
        } catch let error as TranslationError {
            throw error
        } catch is URLError {
            throw TranslationError.networkError
        } catch {
            throw TranslationError.invalidResponse
        }
    }
}
