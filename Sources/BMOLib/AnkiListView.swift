import SwiftUI

struct AnkiListView: View {
    let onBack: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var exporter: AnkiExportModel

    /// `phoneticsService` is used to fill in missing IPA at export time.
    /// TranslatorView passes its view model's service through, so #Preview
    /// gets the mock and never shells out to espeak-ng from Xcode Canvas.
    init(onBack: @escaping () -> Void, phoneticsService: PhoneticsService = PhoneticsService()) {
        self.onBack = onBack
        _exporter = StateObject(wrappedValue: AnkiExportModel(phoneticsService: phoneticsService))
    }

    private var hasExported: Bool {
        settings.ankiCards.cards.contains(where: \.isExported)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewHeader(
                title: "Anki",
                onBack: onBack,
                trailing: hasExported ? AnyView(
                    Button(action: { settings.ankiCards.clearExported() }) {
                        Text("Clear exported")
                            .font(.system(size: 11))
                            .foregroundColor(SigTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Remove exported cards from this list (they stay in Anki)")
                ) : nil
            )

            if settings.ankiCards.isEmpty {
                Spacer()
                Text("Bookmark a translation to add it here")
                    .font(.system(size: 12.5))
                    .foregroundColor(SigTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(settings.ankiCards.cards) { card in
                            AnkiCardRow(
                                card: card,
                                onDelete: { settings.ankiCards.delete(id: card.id) }
                            )
                        }
                    }
                }
            }

            if let error = exporter.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(SigTheme.errorText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            ExportButton(
                count: settings.ankiCards.pending.count,
                isExporting: exporter.isExporting,
                action: { Task { await exporter.exportPending() } }
            )
            .padding(.top, 10)

            Text("Saved to Downloads · In Anki: File → Import")
                .font(.system(size: 10.5))
                .foregroundColor(SigTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 5)
        }
        .padding(SigSpacing.panelPadding)
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .background(SigTheme.surface)
    }
}

private struct AnkiCardRow: View {
    let card: AnkiCard
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(card.danish)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(SigTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(card.english)
                    .font(.system(size: 11.5))
                    .foregroundColor(SigTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Dim exported cards so the pending ones (what the next export
            // will include) stand out.
            .opacity(card.isExported ? 0.5 : 1)

            if card.isExported {
                Text("Exported")
                    .font(.system(size: 10))
                    .foregroundColor(SigTheme.textMuted)
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(SigTheme.textMuted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(card.isExported ? "Remove from list (stays in Anki)" : "Remove from list")
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

private struct ExportButton: View {
    let count: Int
    let isExporting: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var disabled: Bool { count == 0 || isExporting }

    private var label: String {
        if isExporting { return "Exporting…" }
        switch count {
        case 0: return "Nothing new to export"
        case 1: return "Export 1 new card"
        default: return "Export \(count) new cards"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundColor(disabled ? SigTheme.buttonDisabledText : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SigSpacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: SigRadius.input)
                    .fill(disabled ? SigTheme.buttonDisabledBg
                          : (isHovered ? SigTheme.buttonHover : SigTheme.buttonBg))
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Bookmark button styling

/// Shared by the popover result, the floating result window, and History rows
/// so the bookmark looks and reads the same everywhere.
extension AnkiCardList.MarkState {
    var systemName: String {
        self == .unmarked ? "bookmark" : "bookmark.fill"
    }

    var tint: Color {
        switch self {
        case .unmarked: return SigTheme.textMuted
        case .pending: return SigTheme.accent
        case .exported: return SigTheme.textMuted
        }
    }

    var help: String {
        switch self {
        case .unmarked: return "Save for Anki"
        case .pending: return "Remove from Anki list"
        case .exported: return "Exported to Anki"
        }
    }
}

#Preview {
    AnkiListView(onBack: {}, phoneticsService: PhoneticsService(runner: MockPhoneticsRunner()))
}
