import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
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
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView(settings: AppSettings.shared)
}
