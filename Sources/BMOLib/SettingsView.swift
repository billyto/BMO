import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var keyMonitor = APIKeyMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewHeader(
                title: "Settings",
                onBack: onBack,
                trailing: AnyView(APIKeyBadge(status: keyMonitor.status))
            )
            .onAppear { keyMonitor.verify() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader(label: "macOS Services")
                    SettingsRow(
                        title: "Enable right-click menu",
                        subtitle: "Show \"Translate with BMO\" in context menus",
                        isOn: $settings.servicesEnabled
                    )
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundColor(SigTheme.warn)
                        Text("Changes require app restart to take effect")
                            .font(.system(size: 11))
                            .foregroundColor(SigTheme.warn)
                    }
                    .padding(.bottom, 8)

                    SectionDivider()

                    SettingsSectionHeader(label: "Global Hotkey")
                    SettingsRow(
                        title: "Enable global hotkey",
                        subtitle: "Translate selected text with a keyboard shortcut",
                        isOn: $settings.hotkeyEnabled
                    )
                    if settings.hotkeyEnabled {
                        HStack(spacing: 8) {
                            Text("Shortcut:")
                                .font(.system(size: 12))
                                .foregroundColor(SigTheme.textMuted)
                            Text(settings.hotkey?.displayString ?? "None")
                                .font(.system(size: 12, design: .monospaced))
                                .tracking(0.5)
                                .foregroundColor(SigTheme.textPrimary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(SigTheme.chipBg)
                                .clipShape(RoundedRectangle(cornerRadius: SigRadius.kbd))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SigRadius.kbd)
                                        .stroke(SigTheme.divider, lineWidth: 1)
                                )
                            Text("(Default)")
                                .font(.system(size: 11))
                                .foregroundColor(SigTheme.textMuted)
                        }
                        .padding(.bottom, 10)
                    }

                    SectionDivider()

                    SettingsSectionHeader(label: "Translation Window")
                    SettingsRow(
                        title: "Auto-dismiss floating window",
                        subtitle: "Close automatically after \(Int(settings.autoDismissDuration))s",
                        isOn: $settings.autoDismissEnabled
                    )
                    if settings.autoDismissEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Dismiss after")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(SigTheme.textMuted)
                                Spacer()
                                Text("\(Int(settings.autoDismissDuration))s")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(SigTheme.accent)
                            }
                            HStack(spacing: 8) {
                                Text("5s")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(SigTheme.textMuted)
                                    .frame(width: 22, alignment: .leading)
                                Slider(value: $settings.autoDismissDuration, in: 5...30, step: 5)
                                    .tint(SigTheme.accent)
                                Text("30s")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(SigTheme.textMuted)
                                    .frame(width: 26, alignment: .trailing)
                            }
                        }
                        .padding(.bottom, 12)
                    }

                    SectionDivider()

                    SettingsSectionHeader(label: "Behaviour")
                    SettingsRow(
                        title: "Auto-translate on pause",
                        subtitle: "Translate automatically when you stop typing for 1s",
                        isOn: $settings.autoTranslateEnabled
                    )
                    SettingsRow(
                        title: "History",
                        subtitle: "Save recent translations for quick access",
                        isOn: $settings.historyEnabled
                    )
                }
            }

            Text("Changes are saved automatically")
                .font(.system(size: 11))
                .foregroundColor(SigTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
        .padding(SigSpacing.panelPadding)
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .background(SigTheme.surface)
    }
}

private struct SettingsSectionHeader: View {
    let label: String
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .foregroundColor(SigTheme.textMuted)
            .padding(.bottom, 2)
    }
}

private struct SettingsRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SigTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(SigTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(SigTheme.accent)
        }
        .padding(.vertical, 10)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(SigTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

// MARK: - DeepL API-key status pill

private struct APIKeyBadge: View {
    let status: APIKeyMonitor.Status

    private var dotColor: Color {
        switch status {
        case .missing: return SigTheme.errorText
        case .invalid, .unreachable: return SigTheme.warn
        case .valid: return SigTheme.success
        case .checking: return SigTheme.textMuted
        }
    }

    private var helpText: String {
        switch status {
        case .missing: return "DEEPL_API_KEY not set in environment"
        case .checking: return "Checking DeepL API key…"
        case .valid: return "DeepL API key is valid"
        case .invalid: return "DeepL rejected the API key"
        case .unreachable: return "Could not reach DeepL — check your connection"
        }
    }

    var body: some View {
        Button(action: APIKeyMonitor.shared.verify) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Text("DeepL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(SigTheme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(dotColor.opacity(0.15)))
            .overlay(Capsule().stroke(dotColor.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: status)
        .help(helpText)
    }
}

// MARK: - Shared header used by Settings and History

struct ViewHeader: View {
    let title: String
    let onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SigTheme.textMuted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Back")

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SigTheme.textPrimary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.bottom, 12)
    }
}

#Preview {
    SettingsView(onBack: {})
}
