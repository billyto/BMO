import SwiftUI
import Foundation

// MARK: - OKLCH → sRGB
// SwiftUI's Color takes sRGB; the design spec uses OKLCH (Oklab cylindrical).
// Reference: https://bottosson.github.io/posts/oklab/

extension Color {
    /// Construct a SwiftUI Color from an OKLCH triplet matching the design spec.
    /// - Parameters:
    ///   - l: lightness, 0–1 (the spec writes this as a percent, e.g. `52%` → 0.52)
    ///   - c: chroma, typically 0–0.4
    ///   - h: hue in degrees, 0–360
    static func oklch(l: Double, c: Double, h: Double) -> Color {
        let (r, g, b) = OKLCHConversion.toSRGB(l: l, c: c, h: h)
        return Color(red: r, green: g, blue: b)
    }
}

private enum OKLCHConversion {
    static func toSRGB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let hRad = h * .pi / 180
        let aComp = c * cos(hRad)
        let bComp = c * sin(hRad)

        let lPrime = l + 0.3963377774 * aComp + 0.2158037573 * bComp
        let mPrime = l - 0.1055613458 * aComp - 0.0638541728 * bComp
        let sPrime = l - 0.0894841775 * aComp - 1.2914855480 * bComp

        let lCubed = lPrime * lPrime * lPrime
        let mCubed = mPrime * mPrime * mPrime
        let sCubed = sPrime * sPrime * sPrime

        let rLinear =  4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed
        let gLinear = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed
        let bLinear = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed

        return (gammaEncode(rLinear), gammaEncode(gLinear), gammaEncode(bLinear))
    }

    private static func gammaEncode(_ x: Double) -> Double {
        let clamped = max(0, min(1, x))
        return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1.0/2.4) - 0.055
    }
}

// MARK: - Theme tokens
// Names mirror the `cs` color scheme in the prototype's React reference.
// Accent hue is 23 (warm orange) per the design spec.

enum SigTheme {
    static let accent       = Color.oklch(l: 0.52, c: 0.19, h: 23)
    static let accentLight  = Color.oklch(l: 0.94, c: 0.06, h: 23)
    static let buttonBg     = Color.oklch(l: 0.52, c: 0.19, h: 23)
    static let buttonHover  = Color.oklch(l: 0.46, c: 0.19, h: 23)
    static let buttonDisabledBg   = Color.oklch(l: 0.91, c: 0.01, h: 240)
    static let buttonDisabledText = Color.oklch(l: 0.68, c: 0.01, h: 240)

    static let surface      = Color.white
    static let inputBg      = Color.oklch(l: 0.985, c: 0.005, h: 240)
    static let inputBorder  = Color.oklch(l: 0.88, c: 0.01, h: 240)
    static let resultBg     = Color.oklch(l: 0.96, c: 0.04, h: 23)
    static let resultBorder = Color.oklch(l: 0.88, c: 0.08, h: 23)
    static let chipBg       = Color.oklch(l: 0.93, c: 0.04, h: 23)
    static let swapHoverBg  = Color.oklch(l: 0.92, c: 0.06, h: 23)
    static let divider      = Color.oklch(l: 0.91, c: 0.01, h: 240)

    static let textPrimary  = Color.oklch(l: 0.20, c: 0.01, h: 240)
    static let textMuted    = Color.oklch(l: 0.58, c: 0.01, h: 240)

    static let success      = Color.oklch(l: 0.52, c: 0.15, h: 145)
    static let warn         = Color.oklch(l: 0.58, c: 0.14, h: 60)
    static let errorBg      = Color.oklch(l: 0.97, c: 0.04, h: 10)
    static let errorBorder  = Color.oklch(l: 0.88, c: 0.08, h: 10)
    static let errorText    = Color.oklch(l: 0.42, c: 0.18, h: 15)
}

// MARK: - Spacing tokens

enum SigSpacing {
    static let popoverWidth: CGFloat = 360
    static let panelPadding: CGFloat = 18
    static let sectionGap: CGFloat = 10
    static let itemGap: CGFloat = 8
    static let inputMinHeight: CGFloat = 80
    static let inputMinHeightCompact: CGFloat = 64
    static let resultMinHeight: CGFloat = 66
    static let resultMinHeightCompact: CGFloat = 56
    static let buttonVerticalPadding: CGFloat = 9
    static let footerButtonSize: CGFloat = 28
}

// MARK: - Radius tokens

enum SigRadius {
    static let panel: CGFloat = 16
    static let input: CGFloat = 8
    static let chip: CGFloat = 5
    static let footerButton: CGFloat = 7
    static let badge: CGFloat = 20
    static let kbd: CGFloat = 6
}
