import AppKit
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var translationService: TranslationService?
    private var serviceProvider: ServiceProvider!
    private var hotkeyMonitor: HotkeyMonitor?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        if isAnotherInstanceRunning() {
            NSLog("Another instance of BMO is already running. Terminating this instance.")
            NSApp.terminate(nil)
            return
        }

        // Try to bring up the translation service. If DEEPL_API_KEY is missing
        // or invalid we keep going with a nil service — APIKeyMonitor signals
        // the state via the Settings DeepL badge (red = missing, yellow =
        // invalid) and translate() returns a clear error rather than the app
        // exiting at launch.
        if let apiKey = ProcessInfo.processInfo.environment["DEEPL_API_KEY"], !apiKey.isEmpty {
            do {
                let networkClient = URLSessionNetworkClient()
                translationService = try TranslationService(apiKey: apiKey, networkClient: networkClient)
            } catch {
                NSLog("Failed to initialize translation service: \(error)")
            }
        } else {
            NSLog("DEEPL_API_KEY is not set — app will launch in unconfigured state")
        }

        // Kick off the live key-status check so the Settings indicator can
        // tell the user whether DeepL is actually accepting the key.
        APIKeyMonitor.shared.verify()

        // Initialize service provider for macOS Services (if enabled). The
        // provider reads DEEPL_API_KEY itself and handles a missing key by
        // surfacing an error notification — no need to gate it on
        // translationService.
        if AppSettings.shared.servicesEnabled {
            serviceProvider = ServiceProvider()
            NSApp.servicesProvider = serviceProvider
            NSLog("macOS Services enabled")
        } else {
            NSLog("macOS Services disabled")
        }

        // Global hotkey only makes sense with a working service; otherwise the
        // event tap would intercept the combo but produce no translation.
        if let translationService {
            let monitor = HotkeyMonitor(translationService: translationService)
            monitor.start()
            hotkeyMonitor = monitor
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

        // Create popover — passes the (possibly nil) translation service through
        // so the popover renders even without a key. The DeepL badge in
        // Settings shows red and translate() reports a clear error.
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TranslatorView(
                translationService: translationService
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

    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications

        // For debug builds (raw executables), check by process name
        // For release builds (app bundles), check by bundle identifier
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            // App bundle - use bundle identifier
            let instanceCount = runningApps.filter { app in
                app.bundleIdentifier == bundleIdentifier
            }.count
            return instanceCount > 1
        } else {
            // Raw executable - use process name
            let processName = ProcessInfo.processInfo.processName
            let instanceCount = runningApps.filter { app in
                app.localizedName == processName || app.bundleURL?.lastPathComponent.contains(processName) == true
            }.count
            NSLog("Checking for duplicate instances by process name '\(processName)': found \(instanceCount)")
            return instanceCount > 1
        }
    }

}
