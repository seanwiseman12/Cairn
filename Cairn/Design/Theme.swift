import SwiftUI
import UIKit

/// "Topographic Field Journal" design tokens, taken from the hand-drawn topo map
/// style reference: taupe ground, dark-brown contour lines, cream lettering.
/// Every color adapts to dark mode ("night map"), so views should use these
/// instead of hard-coded colors.
enum Theme {
    /// Screen background behind the contour lines. Slightly darker than the
    /// reference's #A39B8B so large cream titles keep 3:1 contrast.
    static let khaki       = Color(light: 0x968D7D, dark: 0x2A241B)
    /// Contour lines on the background.
    static let contourLine = Color(light: 0x4A3F2C, dark: 0x54473A)
    /// Cream lettering for big display titles on the background.
    static let cream       = Color(light: 0xF8F6EA, dark: 0xEFE8D6)
    /// Small text placed directly on the background (dark brown reads better than cream).
    static let groundText  = Color(light: 0x2E271B, dark: 0xEFE8D6)

    /// Card ("journal page") surface and the text on it.
    static let card        = Color(light: 0xF8F6EA, dark: 0x3A3227)
    static let ink         = Color(light: 0x3B3223, dark: 0xEFE8D6)
    static let fadedInk    = Color(light: 0x6F6450, dark: 0xB5AA94)

    /// Accents.
    static let forest      = Color(light: 0x2F5D46, dark: 0x6FAE8C)
    static let rust        = Color(light: 0xB5562E, dark: 0xDB7A50)
    static let sky         = Color(light: 0x4F7A94, dark: 0x86AFC8)
}

/// The two typefaces from the style reference, bundled in Resources/Fonts.
enum JournalFont {
    /// Condensed, all-caps display face (Bebas Neue).
    static let display = "BebasNeue-Regular"
    /// Old-style italic serif (IM Fell English Italic).
    static let script = "IM_FELL_English_Italic"
}

extension Font {
    /// Bebas Neue. Use for screen titles, numbers, labels and buttons.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(JournalFont.display, size: size, relativeTo: style)
    }

    /// IM Fell English Italic. Use for names, taglines and card titles.
    static func script(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(JournalFont.script, size: size, relativeTo: style)
    }
}

extension View {
    /// Small spaced-out label like "ELEVATION".
    func journalLabel() -> some View {
        font(.display(15, relativeTo: .caption))
            .tracking(1.6)
            .foregroundStyle(Theme.fadedInk)
    }

    /// A page "taped into" the journal: cream paper, thin ink border, soft shadow.
    func journalCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    /// Worn, letterpress-style speckles over big display lettering, like the reference.
    func speckled(_ color: Color = Theme.khaki.opacity(0.55)) -> some View {
        overlay {
            Speckle(color: color).mask { self }
        }
    }
}

/// Big filled button in forest green with display lettering.
struct JournalButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(24, relativeTo: .headline))
            .tracking(1.2)
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.forest, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

/// Text field drawn as a paper box with an ink border.
struct JournalFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.22), lineWidth: 1)
            )
            .foregroundStyle(Theme.ink)
    }
}

extension Color {
    /// A color with separate light- and dark-mode hex values, e.g. 0xF8F6EA.
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
