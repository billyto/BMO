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

// MARK: - App Version

enum AppVersion {
    /// "v1.7 (1.7.0)", or "dev build" when running outside a real app bundle
    /// (raw SPM binary, Xcode dev runs) — those lack the bundle identifier
    /// needed for Bundle.main to expose Info.plist's version keys.
    static var displayString: String {
        guard let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return "dev build"
        }
        return "v\(shortVersion) (\(buildVersion))"
    }
}
