import Foundation

/// Tracks the live status of `DEEPL_API_KEY` so the Settings view can render a
/// traffic-light indicator (missing → red, invalid → yellow, valid → green).
///
/// Verification hits DeepL's `/v2/usage` endpoint — a no-op auth check that
/// returns 200 for valid keys without consuming translation quota.
@MainActor
final class APIKeyMonitor: ObservableObject {
    static let shared = APIKeyMonitor()

    enum Status: Equatable {
        case missing      // env var not set or empty string
        case checking     // verification request in flight
        case valid        // DeepL accepted the key
        case invalid      // DeepL rejected the key (401 / 403)
        case unreachable  // network error — we don't know
    }

    @Published private(set) var status: Status = .missing

    private var verifyTask: Task<Void, Never>?

    private init() {}

    /// Re-read the env var and (if present) verify against DeepL. Cancels any
    /// in-flight verification.
    func verify() {
        verifyTask?.cancel()

        let key = ProcessInfo.processInfo.environment["DEEPL_API_KEY"] ?? ""
        guard !key.isEmpty else {
            status = .missing
            return
        }

        status = .checking
        verifyTask = Task { @MainActor [weak self] in
            let result = await Self.callUsage(key: key)
            guard !Task.isCancelled, let self else { return }
            self.status = result
        }
    }

    private static func callUsage(key: String) async -> Status {
        // DeepL free keys end in ":fx" and live at api-free; pro keys use api.
        let host = key.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        guard let url = URL(string: "https://\(host)/v2/usage") else {
            return .unreachable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            switch http.statusCode {
            case 200..<300:
                return .valid
            case 401, 403:
                return .invalid
            case 456:
                // Quota exceeded — key itself is valid, just out of characters.
                return .valid
            default:
                // Anything else (5xx, unexpected) — treat as can't-verify rather
                // than declaring the key invalid.
                return .unreachable
            }
        } catch {
            return .unreachable
        }
    }
}
