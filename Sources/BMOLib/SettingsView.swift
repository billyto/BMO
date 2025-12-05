import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var refreshID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Settings")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // macOS Services settings
            VStack(alignment: .leading, spacing: 12) {
                Text("macOS Services")
                    .font(.headline)

                Toggle(isOn: $settings.servicesEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable right-click Services menu")
                            .font(.body)
                        Text("Show \"Translate with BMO\" in right-click context menus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .id("services-\(settings.servicesEnabled)")

                if settings.servicesEnabled {
                    Text("Requires app restart to take effect")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.leading, 20)
                }
            }

            Divider()

            // Global Hotkey settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkey")
                    .font(.headline)

                Toggle(isOn: $settings.hotkeyEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable global hotkey")
                            .font(.body)
                        Text("Translate selected text with a keyboard shortcut")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .id("hotkey-\(settings.hotkeyEnabled)")

                if settings.hotkeyEnabled {
                    HStack {
                        Text("Shortcut:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(settings.hotkey?.displayString ?? "None")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        Text("(Default: ⌘⇧T)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }

            Divider()

            // Auto-dismiss settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Translation Window")
                    .font(.headline)

                Toggle(isOn: $settings.autoDismissEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-dismiss floating window")
                            .font(.body)
                        Text("Automatically close the translation window after \(Int(settings.autoDismissDuration)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .id("autodismiss-\(settings.autoDismissEnabled)")

                if settings.autoDismissEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dismiss after: \(Int(settings.autoDismissDuration)) seconds")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("5s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $settings.autoDismissDuration, in: 5...30, step: 5)
                            Text("30s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }

            Spacer()

            // Footer
            Text("Changes are saved automatically")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: 400, height: 500)
        .fixedSize()
        .id(refreshID)
        .onAppear {
            // Force immediate refresh to fix toggle rendering in popover
            refreshID = UUID()
        }
    }
}

#Preview {
    SettingsView()
}
