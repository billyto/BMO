import Foundation
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private let autoDismissEnabledKey = "autoDismissEnabled"
    private let autoDismissDurationKey = "autoDismissDuration"

    // Published properties
    @Published var autoDismissEnabled: Bool {
        didSet {
            defaults.set(autoDismissEnabled, forKey: autoDismissEnabledKey)
        }
    }

    @Published var autoDismissDuration: Double {
        didSet {
            defaults.set(autoDismissDuration, forKey: autoDismissDurationKey)
        }
    }

    private init() {
        // Load saved values or use defaults
        self.autoDismissEnabled = defaults.object(forKey: autoDismissEnabledKey) as? Bool ?? true
        self.autoDismissDuration = defaults.object(forKey: autoDismissDurationKey) as? Double ?? 15.0
    }

    // Computed property for actual timeout to use
    var effectiveTimeout: Double {
        return autoDismissEnabled ? autoDismissDuration : 0
    }
}
