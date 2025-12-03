import Foundation
import AppKit
import Carbon

@MainActor
class HotkeyMonitor: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var translationService: TranslationService?

    init(translationService: TranslationService) {
        self.translationService = translationService
    }

    func start() {
        guard AppSettings.shared.hotkeyEnabled else { return }

        // Check if we have accessibility permissions
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermissions()
            return
        }

        stop() // Stop any existing tap

        // Create event tap for key events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("Hotkey monitor started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard let hotkey = AppSettings.shared.hotkey,
              AppSettings.shared.hotkeyEnabled else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.maskShift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.maskAlternate) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.maskControl) {
            modifiers |= UInt32(controlKey)
        }

        // Check if this matches our hotkey
        if keyCode == hotkey.keyCode && modifiers == hotkey.modifiers {
            // Trigger translation
            Task { @MainActor in
                self.handleHotkeyPressed()
            }
            // Consume the event (don't pass it through)
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleHotkeyPressed() {
        NSLog("Hotkey pressed!")

        // Get selected text from the system
        guard let selectedText = getSelectedText() else {
            NSLog("No text selected")
            showNotification(title: "BMO", message: "No text selected")
            return
        }

        NSLog("Selected text: \(selectedText.prefix(50))...")

        // Check text length
        if selectedText.count > 5000 {
            showNotification(title: "BMO Translation Error", message: "Text too long. Please select less than 5000 characters.")
            return
        }

        guard let translationService = translationService else {
            NSLog("Translation service not available")
            return
        }

        // Perform translation
        Task {
            do {
                // Try Danish -> English first
                let result = try await translationService.translate(
                    text: selectedText,
                    from: .danish,
                    to: .english
                )

                NSLog("Translation successful")
                showTranslationResult(original: selectedText, translated: result)
            } catch {
                // Try English -> Danish
                do {
                    let result = try await translationService.translate(
                        text: selectedText,
                        from: .english,
                        to: .danish
                    )

                    NSLog("Translation successful (EN->DA)")
                    showTranslationResult(original: selectedText, translated: result)
                } catch {
                    NSLog("Translation failed: \(error)")
                    showNotification(title: "BMO Translation Error", message: "Translation failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func getSelectedText() -> String? {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedContents = pasteboard.string(forType: .string)

        // Simulate Cmd+C to copy selected text
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // C key
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand

        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)

        // Small delay to let the copy complete
        Thread.sleep(forTimeInterval: 0.1)

        // Get the copied text
        let copiedText = pasteboard.string(forType: .string)

        // Restore original clipboard if it was different
        if copiedText != savedContents {
            if let saved = savedContents {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }

        return copiedText
    }

    private func showTranslationResult(original: String, translated: String) {
        let window = TranslationResultWindow(original: original, translated: translated)
        window.show()
    }

    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func requestAccessibilityPermissions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "BMO needs accessibility permissions to enable the global hotkey feature. Please grant access in System Settings → Privacy & Security → Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings to Accessibility
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    nonisolated deinit {
        // Note: Can't call stop() from deinit due to actor isolation
        // The system will clean up the event tap when the port is released
    }
}
