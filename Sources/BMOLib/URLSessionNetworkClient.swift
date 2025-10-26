import Foundation

// MARK: - URLSession Network Client

final class URLSessionNetworkClient: NetworkClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func performRequest(url: URL, body: [String: String], headers: [String: String]) async throws -> DeepLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Set headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Create form-encoded body
        let formData = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        request.httpBody = formData.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.invalidResponse
            }

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode the response
                let decoder = JSONDecoder()
                do {
                    let deeplResponse = try decoder.decode(DeepLResponse.self, from: data)
                    return deeplResponse
                } catch {
                    throw TranslationError.invalidResponse
                }
            case 403:
                throw TranslationError.invalidAPIKey
            case 456:
                throw TranslationError.quotaExceeded
            default:
                throw TranslationError.invalidResponse
            }
        } catch let error as TranslationError {
            throw error
        } catch is URLError {
            throw TranslationError.networkError
        } catch {
            throw TranslationError.invalidResponse
        }
    }
}
