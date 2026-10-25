import SwiftUI
import BMOLib

// The app's UI lives in AppDelegate's menu bar popover. SwiftUI still needs at
// least one scene, so each app below declares an empty Settings scene.
//
// On current macOS, SwiftUI opens an app's only scene at launch, which showed
// an empty "Sig Settings" window (#18). `.defaultLaunchBehavior(.suppressed)`
// prevents that, but it's macOS 15+ and SceneBuilder can't do `if #available`,
// so main.swift picks the app at runtime.

@available(macOS 15.0, *)
struct BMOApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}

/// macOS 14 has no way to suppress the launch window; same app otherwise.
struct BMOAppMacOS14: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
