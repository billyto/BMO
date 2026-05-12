import Foundation
import Combine
import Carbon

// Hotkey configuration
struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        // Convert keyCode to character
        let keyString = Hotkey.keyCodeToString(keyCode)
        parts.append(keyString)

        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        default: return "?"
        }
    }
}

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let historyMaxCount = 20

    private let defaults = UserDefaults.standard

    // Keys
    private let autoDismissEnabledKey = "autoDismissEnabled"
    private let autoDismissDurationKey = "autoDismissDuration"
    private let hotkeyEnabledKey = "hotkeyEnabled"
    private let hotkeyDataKey = "hotkeyData"
    private let servicesEnabledKey = "servicesEnabled"
    private let autoTranslateEnabledKey = "autoTranslateEnabled"
    private let historyEnabledKey = "historyEnabled"
    private let historyKey = "translationHistory"

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

    @Published var hotkeyEnabled: Bool {
        didSet {
            defaults.set(hotkeyEnabled, forKey: hotkeyEnabledKey)
        }
    }

    @Published var servicesEnabled: Bool {
        didSet {
            defaults.set(servicesEnabled, forKey: servicesEnabledKey)
        }
    }

    @Published var hotkey: Hotkey? {
        didSet {
            if let hotkey = hotkey {
                if let encoded = try? JSONEncoder().encode(hotkey) {
                    defaults.set(encoded, forKey: hotkeyDataKey)
                }
            } else {
                defaults.removeObject(forKey: hotkeyDataKey)
            }
        }
    }

    @Published var autoTranslateEnabled: Bool {
        didSet {
            defaults.set(autoTranslateEnabled, forKey: autoTranslateEnabledKey)
        }
    }

    @Published var historyEnabled: Bool {
        didSet {
            defaults.set(historyEnabled, forKey: historyEnabledKey)
        }
    }

    @Published var translationHistory: [HistoryItem] {
        didSet {
            if let data = try? JSONEncoder().encode(translationHistory) {
                defaults.set(data, forKey: historyKey)
            }
        }
    }

    private init() {
        // Load saved values or use defaults
        self.autoDismissEnabled = defaults.object(forKey: autoDismissEnabledKey) as? Bool ?? true
        self.autoDismissDuration = defaults.object(forKey: autoDismissDurationKey) as? Double ?? 15.0
        self.hotkeyEnabled = defaults.object(forKey: hotkeyEnabledKey) as? Bool ?? true
        self.servicesEnabled = defaults.object(forKey: servicesEnabledKey) as? Bool ?? true

        // Load hotkey or use default (⌘⇧T)
        if let data = defaults.data(forKey: hotkeyDataKey),
           let decoded = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.hotkey = decoded
        } else {
            // Default: Command + Shift + T
            self.hotkey = Hotkey(keyCode: 17, modifiers: UInt32(cmdKey | shiftKey))
        }

        // New v1.6 settings — default off so existing users opt in via the redesigned
        // Settings UI rather than getting behavior changes silently.
        self.autoTranslateEnabled = defaults.object(forKey: autoTranslateEnabledKey) as? Bool ?? false
        self.historyEnabled = defaults.object(forKey: historyEnabledKey) as? Bool ?? false

        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.translationHistory = decoded
        } else {
            self.translationHistory = []
        }
    }

    // Computed property for actual timeout to use
    var effectiveTimeout: Double {
        return autoDismissEnabled ? autoDismissDuration : 0
    }

    // MARK: - History helpers

    /// Insert a new translation at the head, FIFO-trim to `historyMaxCount`.
    /// No-op when `historyEnabled == false` so disabling the toggle prevents recording.
    func recordTranslation(source: String, translation: String, from: Language, to: Language) {
        guard historyEnabled else { return }
        let item = HistoryItem(
            sourceText: source,
            translatedText: translation,
            sourceLang: from,
            targetLang: to
        )
        var updated = translationHistory
        updated.insert(item, at: 0)
        if updated.count > Self.historyMaxCount {
            updated = Array(updated.prefix(Self.historyMaxCount))
        }
        translationHistory = updated
    }

    func clearHistory() {
        translationHistory = []
    }

    func deleteHistoryItem(id: UUID) {
        translationHistory.removeAll { $0.id == id }
    }
}
