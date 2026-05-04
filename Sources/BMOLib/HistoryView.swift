import SwiftUI

struct HistoryView: View {
    let onBack: () -> Void
    let onSelect: (HistoryItem) -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewHeader(
                title: "History",
                onBack: onBack,
                trailing: settings.translationHistory.isEmpty ? nil : AnyView(
                    Button(action: settings.clearHistory) {
                        Text("Clear all")
                            .font(.system(size: 11))
                            .foregroundColor(SigTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all history")
                )
            )

            if settings.translationHistory.isEmpty {
                Spacer()
                Text("No history yet")
                    .font(.system(size: 12.5))
                    .foregroundColor(SigTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(settings.translationHistory) { item in
                            HistoryRow(
                                item: item,
                                onSelect: { onSelect(item) },
                                onDelete: { settings.deleteHistoryItem(id: item.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding(SigSpacing.panelPadding)
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .background(SigTheme.surface)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    private var directionLabel: String {
        "\(item.sourceLang.rawValue)→\(item.targetLang.rawValue)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.sourceText)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(SigTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.translatedText)
                        .font(.system(size: 11.5))
                        .foregroundColor(SigTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Text(directionLabel)
                    .font(.system(size: 10))
                    .foregroundColor(SigTheme.textMuted)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(SigTheme.textMuted)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: SigRadius.chip)
                .fill(isHovered ? SigTheme.chipBg : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

#Preview {
    HistoryView(onBack: {}, onSelect: { _ in })
}
