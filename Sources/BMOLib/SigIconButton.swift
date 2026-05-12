import SwiftUI

/// Small icon button shared across the popover, result window, and any future
/// surfaces that need the "tinted SF Symbol on a hover-chip background" look.
/// Defaults match the popover's inline action buttons; pass non-default
/// `frameSize` / `iconSize` for the slightly more compact result-window
/// variant.
struct SigIconButton: View {
    let systemName: String
    let tint: Color
    let help: String
    let action: () -> Void
    var frameSize: CGFloat = 24
    var iconSize: CGFloat = 13
    var iconWeight: Font.Weight = .regular

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundColor(tint)
                .frame(width: frameSize, height: frameSize)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? SigTheme.chipBg.opacity(0.6) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }

    /// 22pt frame / 12pt medium icon — used by the floating result window
    /// where space is tighter than in the popover.
    static func compact(
        systemName: String,
        tint: Color,
        help: String,
        action: @escaping () -> Void
    ) -> SigIconButton {
        SigIconButton(
            systemName: systemName,
            tint: tint,
            help: help,
            action: action,
            frameSize: 22,
            iconSize: 12,
            iconWeight: .medium
        )
    }
}
