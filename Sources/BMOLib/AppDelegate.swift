import AppKit
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var translationService: TranslationService!

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize translation service
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            showAPIKeyAlert()
            return
        }

        do {
            let networkClient = URLSessionNetworkClient()
            translationService = try TranslationService(apiKey: apiKey, networkClient: networkClient)
        } catch {
            showAPIKeyAlert()
            return
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Try to load custom icon first, fallback to SF Symbol
            if let customIcon = loadMenuBarIcon() {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "service.dog", accessibilityDescription: "BMO Translator")
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TranslatorView(translationService: translationService)
        )
    }

    @MainActor
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate the app to ensure the popover gets focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func loadMenuBarIcon() -> NSImage? {
        // Try to load from Resources folder
        if let iconURL = Bundle.module.url(forResource: "menubar-icon", withExtension: "pdf") ??
                         Bundle.module.url(forResource: "menubar-icon", withExtension: "png") {
            if let image = NSImage(contentsOf: iconURL) {
                image.isTemplate = true  // Critical: makes it adapt to light/dark mode
                image.size = NSSize(width: 18, height: 18)  // Standard menu bar icon size
                return image
            }
        }
        return nil
    }

    @MainActor
    private func showAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "API Key Missing"
        alert.informativeText = "Please set the DEEPL_API_KEY environment variable with your DeepL API key."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
