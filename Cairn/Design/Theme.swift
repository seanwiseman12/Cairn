import SwiftUI
import UIKit

/// Cairn's design tokens: a dark, photographic outdoors look. Near-black
/// charcoal screens, dark grey rounded cards, white text and a stark white
/// accent (selected states, primary buttons, highlights). The app always runs
/// in dark mode (see RootView), so each color has a single value.
enum Theme {
    /// Screen background and the cards that sit on it.
    static let background    = Color(hex: 0x111311)
    static let surface       = Color(hex: 0x1D201D)
    /// Fill for text fields, unselected chips, icon tiles and round icon buttons.
    static let surfaceMuted  = Color(hex: 0x2A2D2A)
    static let border        = Color.white.opacity(0.08)

    static let textPrimary   = Color(hex: 0xF3F4EF)
    static let textSecondary = Color(hex: 0x989D97)

    /// Raised feature cards (rank card, empty states, the tab bar).
    static let forest        = Color(hex: 0x232723)
    /// Text and icons on raised cards.
    static let onForest      = Color(hex: 0xF3F4EF)
    static let onForestMuted = Color(hex: 0xF3F4EF).opacity(0.62)

    /// The accent: selected chips and tabs, primary buttons, progress, highlights.
    static let accent        = Color.white
    /// Text and icons on the accent.
    static let onAccent      = Color(hex: 0x141614)
    static let star          = Color(hex: 0xF4BE52)
    static let danger        = Color(hex: 0xEC7A64)

    /// The globe: white continents (the same white as the buttons) on a dark
    /// charcoal sea, with soft grey contour lines on land and faint ones at sea.
    static let globeLand     = accent
    static let globeSea      = Color(hex: 0x202420)
    static let globeLandInk  = Color(hex: 0xA3A8A2)
    static let globeSeaInk   = Color(hex: 0x3A4236)

    /// The home screen's backdrop, misty dark green at the top down to charcoal.
    static let homeSky       = Color(hex: 0x3C4A40)
    static let homeMid       = Color(hex: 0x1E2820)
    static let homeDeep      = Color(hex: 0x111311)
    /// Secondary text on the home backdrop.
    static let homeMuted     = Color(hex: 0xB9C0B8)

    enum Radius {
        /// Big hero and feature cards.
        static let hero: CGFloat = 32
        /// Ordinary cards and sheets.
        static let card: CGFloat = 24
        /// Text fields and icon tiles.
        static let field: CGFloat = 18
    }
}

/// Cairn's typeface: Outfit, a geometric sans (bundled, SIL Open Font License).
/// Use `.font(.cairn(.headline))` or `.font(.cairn(.body, weight: .semibold))`
/// in place of the system text styles. Sizes still follow Dynamic Type.
extension Font {
    static func cairn(_ style: TextStyle, weight: Weight? = nil) -> Font {
        let defaultWeight: Weight = style == .headline ? .semibold : .regular
        return .custom(outfitName(weight ?? defaultWeight), size: pointSize(style), relativeTo: style)
    }

    static func cairn(size: CGFloat, weight: Weight = .regular, relativeTo style: TextStyle = .body) -> Font {
        .custom(outfitName(weight), size: size, relativeTo: style)
    }

    private static func outfitName(_ weight: Weight) -> String {
        switch weight {
        case .medium: "Outfit-Medium"
        case .semibold: "Outfit-SemiBold"
        case .bold, .heavy, .black: "Outfit-Bold"
        default: "Outfit-Regular"
        }
    }

    /// Default point sizes of the system text styles (Large text size).
    private static func pointSize(_ style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

extension View {
    /// Dark grey rounded card with a hairline edge.
    func card(padding: CGFloat = 16, radius: CGFloat = Theme.Radius.card) -> some View {
        self.padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    /// Raised feature card: a slightly lighter grey with a soft top-down sheen.
    func forestCard(padding: CGFloat = 18, radius: CGFloat = Theme.Radius.card) -> some View {
        self.padding(padding)
            .background(
                LinearGradient(colors: [Color(hex: 0x2C312C), Theme.forest], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Big filled white capsule button, like the reference's "Start your trip".
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cairn(.headline))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.accent, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

/// Frosted-glass capsule button for use on top of green cards or photos
/// (the reference's "Start Adventure" button).
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cairn(.headline))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial.opacity(0.85), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .environment(\.colorScheme, .dark)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Rounded, softly filled text field.
struct CairnFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
    }
}

extension Color {
    /// A color from a hex value, e.g. 0x1E3A2A.
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A color with separate light- and dark-mode hex values, e.g. 0x1E3A2A.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
