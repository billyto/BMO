import Foundation
import AppKit

@MainActor
@objc public class ServiceProvider: NSObject {
    private var translationService: TranslationService?
    private var resultWindow: TranslationResultWindow?

    public override init() {
        super.init()

        // Initialize translation service
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            NSLog("BMO Service: DEEPL_API_KEY not found in environment")
            return
        }

        do {
            let networkClient = URLSessionNetworkClient()
            translationService = try TranslationService(apiKey: apiKey, networkClient: networkClient)
            NSLog("BMO Service: Translation service initialized successfully")
        } catch {
            NSLog("BMO Service: Failed to initialize translation service: \(error)")
        }
    }

    @objc func translateText(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        NSLog("BMO Service: translateText called")

        // Get the selected text from the pasteboard
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            NSLog("BMO Service: No text found on pasteboard")
            let message = "No text selected"
            error.pointee = message as NSString
            showError(message)
            return
        }

        NSLog("BMO Service: Received text (\(text.count) chars)")

        // Check if translation service is available
        guard let translationService = translationService else {
            NSLog("BMO Service: Translation service not available")
            let message = "Translation service not initialized. Please ensure DEEPL_API_KEY is set."
            error.pointee = message as NSString
            showError(message)
            return
        }

        // Check text length
        if text.count > 5000 {
            let message = "Text too long. Please select less than 5000 characters."
            error.pointee = message as NSString
            showError(message)
            return
        }

        // Perform translation asynchronously — pin to MainActor so the
        // showTranslationResult / showError calls (which touch NSWindow / pasteboard)
        // are valid under Swift 6 strict concurrency.
        Task { @MainActor in
            do {
                let result = try await translationService.autoTranslate(text: text)
                NSLog("BMO Service: Translation successful (detected: \(result.detectedSource?.rawValue ?? "unknown"))")
                self.showTranslationResult(original: text, translated: result.translated)
            } catch {
                NSLog("BMO Service: Translation failed: \(error)")
                self.showError("Translation failed: \(error.localizedDescription)")
            }
        }
    }

    private func showTranslationResult(original: String, translated: String) {
        // Close existing window if any
        resultWindow?.close()

        // Create and show new result window
        resultWindow = TranslationResultWindow(original: original, translated: translated)
        resultWindow?.show()
    }

    private func showError(_ message: String) {
        // Show error notification
        let notification = NSUserNotification()
        notification.title = "BMO Translation Error"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
