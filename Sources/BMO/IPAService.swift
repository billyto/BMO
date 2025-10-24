import Foundation

/// Service for fetching IPA (International Phonetic Alphabet) pronunciations
class IPAService {
    private var cache: [String: String] = [:]

    /// Fetches IPA pronunciation for a given word and language
    /// - Parameters:
    ///   - text: The text to get pronunciation for
    ///   - language: The language of the text (danish or english)
    /// - Returns: IPA pronunciation string, or nil if not available
    func fetchIPA(for text: String, language: Language) async throws -> String? {
        // Clean the text - only get IPA for single words or first word of phrase
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWord = cleanText.components(separatedBy: .whitespaces).first ?? cleanText

        // Return cached result if available
        let cacheKey = "\(language.rawValue)_\(firstWord.lowercased())"
        if let cached = cache[cacheKey] {
            return cached
        }

        // Use Free Dictionary API for English
        if language == .english {
            if let ipa = try await fetchEnglishIPA(word: firstWord) {
                cache[cacheKey] = ipa
                return ipa
            }
        }

        // For Danish, we could use other APIs or services
        // For now, return nil if not found
        return nil
    }

    private func fetchEnglishIPA(word: String) async throws -> String? {
        // Properly encode the word for URL safety
        guard let encodedWord = word.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(encodedWord)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Decode using Codable for type safety
            let decoder = JSONDecoder()
            let entries = try decoder.decode([DictionaryAPIResponse].self, from: data)

            // Find first non-empty IPA text
            return entries.first?.phonetics?.first(where: { $0.text?.isEmpty == false })?.text
        } catch {
            // Silently fail - IPA is optional enhancement
            return nil
        }
    }
}

// MARK: - Response Models
struct DictionaryAPIResponse: Codable {
    let word: String?
    let phonetics: [Phonetic]?

    struct Phonetic: Codable {
        let text: String?
        let audio: String?
    }
}
