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
            showError("No text selected")
            return
        }

        NSLog("BMO Service: Received text: \(text.prefix(50))...")

        // Check if translation service is available
        guard let translationService = translationService else {
            NSLog("BMO Service: Translation service not available")
            showError("Translation service not initialized. Please ensure DEEPL_API_KEY is set.")
            return
        }

        // Check text length
        if text.count > 5000 {
            showError("Text too long. Please select less than 5000 characters.")
            return
        }

        // Perform translation asynchronously
        Task {
            do {
                // Auto-detect language by trying to determine if it's Danish or English
                // We'll try Danish->English first, and DeepL will handle detection
                let result = try await translationService.translate(
                    text: text,
                    from: .danish,
                    to: .english
                )

                NSLog("BMO Service: Translation successful")
                self.showTranslationResult(original: text, translated: result)
            } catch {
                NSLog("BMO Service: Translation failed: \(error)")

                // If it failed with Danish->English, try English->Danish
                do {
                    let result = try await translationService.translate(
                        text: text,
                        from: .english,
                        to: .danish
                    )

                    NSLog("BMO Service: Translation successful (EN->DA)")
                    self.showTranslationResult(original: text, translated: result)
                } catch {
                    NSLog("BMO Service: Translation failed both directions: \(error)")
                    self.showError("Translation failed: \(error.localizedDescription)")
                }
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
