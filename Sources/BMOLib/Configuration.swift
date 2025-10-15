import Foundation

// MARK: - API Configuration

struct APIConfiguration {
    let baseURL: String
    let apiKey: String

    static let deepL = APIConfiguration(
        baseURL: "https://api-free.deepl.com/v2/translate",
        apiKey: ProcessInfo.processInfo.environment["DEEPL_API_KEY"] ?? ""
    )

    static func custom(baseURL: String, apiKey: String) -> APIConfiguration {
        return APIConfiguration(baseURL: baseURL, apiKey: apiKey)
    }
}
