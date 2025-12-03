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
        case 18...29: return "\(keyCode - 18 + 1)" // Numbers 1-9, 0
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

    private let defaults = UserDefaults.standard

    // Keys
    private let autoDismissEnabledKey = "autoDismissEnabled"
    private let autoDismissDurationKey = "autoDismissDuration"
    private let hotkeyEnabledKey = "hotkeyEnabled"
    private let hotkeyDataKey = "hotkeyData"

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

    private init() {
        // Load saved values or use defaults
        self.autoDismissEnabled = defaults.object(forKey: autoDismissEnabledKey) as? Bool ?? true
        self.autoDismissDuration = defaults.object(forKey: autoDismissDurationKey) as? Double ?? 15.0
        self.hotkeyEnabled = defaults.object(forKey: hotkeyEnabledKey) as? Bool ?? true

        // Load hotkey or use default (⌘⇧T)
        if let data = defaults.data(forKey: hotkeyDataKey),
           let decoded = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.hotkey = decoded
        } else {
            // Default: Command + Shift + T
            self.hotkey = Hotkey(keyCode: 17, modifiers: UInt32(cmdKey | shiftKey))
        }
    }

    // Computed property for actual timeout to use
    var effectiveTimeout: Double {
        return autoDismissEnabled ? autoDismissDuration : 0
    }
}
