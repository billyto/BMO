import Foundation

/// Service for fetching IPA (International Phonetic Alphabet) pronunciations
class IPAService {
    private let networkClient: NetworkClient
    private var cache: [String: String] = [:]

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

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
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word.lowercased())"

        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Parse the response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstEntry = json.first,
               let phonetics = firstEntry["phonetics"] as? [[String: Any]] {

                // Try to find IPA text
                for phonetic in phonetics {
                    if let text = phonetic["text"] as? String, !text.isEmpty {
                        return text
                    }
                }
            }

            return nil
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
