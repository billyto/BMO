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

    /// Translate with an explicit source language. Used by the menu-bar popover
    /// where the user has already picked the direction.
    func translate(text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> String {
        let result = try await translate(
            text: text,
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage
        )
        return result.text
    }

    /// Lower-level translate. Pass `sourceLanguage: nil` to let DeepL auto-detect —
    /// the request omits `source_lang` entirely and the detected source comes back
    /// in the response.
    func translate(
        text: String,
        targetLanguage: Language,
        sourceLanguage: Language? = nil
    ) async throws -> (text: String, detectedSource: Language?) {
        guard !text.isEmpty else {
            throw TranslationError.emptyText
        }

        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidResponse
        }

        var body: [String: String] = [
            "text": text,
            "target_lang": targetLanguage.rawValue
        ]
        if let sourceLanguage {
            body["source_lang"] = sourceLanguage.rawValue
        }

        let headers: [String: String] = [
            "Authorization": "DeepL-Auth-Key \(apiKey)"
        ]

        do {
            let response = try await networkClient.performRequest(url: url, body: body, headers: headers)
            guard let translation = response.translations.first else {
                throw TranslationError.invalidResponse
            }
            return (
                text: translation.text,
                detectedSource: Language(rawValue: translation.detectedSourceLanguage)
            )
        } catch let error as TranslationError {
            throw error
        } catch is URLError {
            throw TranslationError.networkError
        } catch {
            throw TranslationError.invalidResponse
        }
    }

    /// Translate when the caller doesn't know the source — typically the Services
    /// menu or the global hotkey, where the user just selected text in some other
    /// app. DeepL auto-detects the source; if it turns out to be English we make a
    /// second call with target=Danish so we never return an English→English no-op.
    /// For any other detected language (French, German, etc.) we keep the
    /// English-targeted result.
    func autoTranslate(text: String) async throws -> (translated: String, detectedSource: Language?) {
        let first = try await translate(text: text, targetLanguage: .english)
        if first.detectedSource == .english {
            let second = try await translate(
                text: text,
                targetLanguage: .danish,
                sourceLanguage: .english
            )
            return (translated: second.text, detectedSource: .english)
        }
        return (translated: first.text, detectedSource: first.detectedSource)
    }
}
