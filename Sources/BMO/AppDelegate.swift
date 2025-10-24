import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var translationService: TranslationService!
    private var ipaService: IPAService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize translation service
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty else {
            showAPIKeyAlert()
            return
        }

        do {
            let networkClient = URLSessionNetworkClient()
            translationService = try TranslationService(apiKey: apiKey, networkClient: networkClient)
            ipaService = IPAService()
        } catch {
            showAPIKeyAlert()
            return
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "service.dog", accessibilityDescription: "BMO Translator")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TranslatorView(
                translationService: translationService,
                ipaService: ipaService
            )
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
