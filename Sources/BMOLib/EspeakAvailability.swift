import Foundation

/// Tracks whether espeak-ng is installed, so Settings can render a status
/// indicator next to the "Show IPA pronunciation" toggle — mirrors
/// `APIKeyMonitor`'s role for the DeepL key.
@MainActor
final class EspeakAvailability: ObservableObject {
    static let shared = EspeakAvailability()

    enum Status: Equatable {
        case checking
        case missing
        case available
    }

    @Published private(set) var status: Status = .checking

    private init() {
        verify()
    }

    /// Re-checks the well-known install locations. Cheap (a couple of
    /// filesystem stats), so safe to call whenever Settings appears.
    func verify() {
        status = .checking
        Task { @MainActor [weak self] in
            self?.status = EspeakNG.isInstalled ? .available : .missing
        }
    }
}
