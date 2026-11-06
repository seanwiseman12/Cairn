import SwiftUI

/// The Cairn logo: a stack of stones with a white capstone.
struct CairnMark: View {
    var size: CGFloat = 64
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(spacing: size * 0.04) {
            Capsule().fill(Theme.accent)
                .frame(width: size * 0.34, height: size * 0.16)
            Capsule().fill(color)
                .frame(width: size * 0.52, height: size * 0.2)
                .offset(x: size * 0.03)
            Capsule().fill(color)
                .frame(width: size * 0.72, height: size * 0.22)
                .offset(x: -size * 0.02)
            Capsule().fill(color)
                .frame(width: size * 0.95, height: size * 0.26)
        }
        .accessibilityHidden(true)
    }
}

/// Big bold screen title, e.g. "Popular".
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.cairn(.largeTitle, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Pill-shaped chip with an icon: white outline and text when selected, grey fill otherwise.
struct Chip: View {
    let title: String
    var symbol: String?
    var isSelected = false
    /// Over a photo: see-through dark capsules with small uppercase labels.
    var onPhoto = false

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.cairn(.footnote, weight: .semibold))
            }
            if onPhoto {
                Text(title.uppercased())
                    .font(.cairn(.caption, weight: .medium))
                    .tracking(0.8)
            } else {
                Text(title)
                    .font(.cairn(.subheadline, weight: .semibold))
            }
        }
        .foregroundStyle(isSelected ? Theme.accent : (onPhoto ? .white.opacity(0.92) : Theme.textPrimary))
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .background(background, in: Capsule())
        .overlay(Capsule().strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.2))
    }

    private var background: Color {
        if onPhoto { return .black.opacity(isSelected ? 0.6 : 0.5) }
        return isSelected ? Theme.accent.opacity(0.08) : Theme.surfaceMuted
    }
}

/// Small icon + text, like "📅 7 days" in the reference.
struct StatChip: View {
    let symbol: String
    let text: String
    /// Use on forest-green cards (white text) or on white cards (green outline pill).
    var onForest = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.cairn(.footnote, weight: .semibold))
            Text(text)
                .font(.cairn(.subheadline, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(onForest ? Theme.onForest : Theme.textPrimary)
        .padding(.horizontal, onForest ? 0 : 12)
        .frame(minHeight: onForest ? 24 : 36)
        .background {
            if !onForest {
                Capsule().fill(Theme.surface)
                Capsule().strokeBorder(Theme.border, lineWidth: 1)
            }
        }
    }
}

/// Dark round icon button (back, bookmark, search in the reference).
struct CircleIconLabel: View {
    let symbol: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.cairn(.body, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.surfaceMuted, in: Circle())
    }
}

/// Rounded white progress bar.
struct LevelProgressBar: View {
    /// 0...1
    let progress: Double
    var onForest = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(onForest ? Color.white.opacity(0.18) : Theme.surfaceMuted)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Level progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// Raised card with an icon in a circle, a title and a message, used
/// when a screen has nothing in it yet.
struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.cairn(.title2))
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.cairn(.title3, weight: .semibold))
                    .foregroundStyle(Theme.onForest)
                Text(message)
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.onForestMuted)
            }
            Spacer(minLength: 0)
        }
        .forestCard(padding: 22)
    }
}

/// Section heading inside a screen, e.g. "Countries".
struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.cairn(.title3, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: 20) {
        CairnMark()
        ScreenTitle(text: "Popular")
        HStack {
            Chip(title: "Hiking", symbol: "figure.hiking", isSelected: true)
            Chip(title: "Camping", symbol: "tent")
        }
        HStack {
            StatChip(symbol: "calendar", text: "12/08 - 18/08")
            StatChip(symbol: "mappin", text: "12 km")
        }
        CircleIconLabel(symbol: "star")
        LevelProgressBar(progress: 0.4)
        EmptyStateCard(symbol: "book.pages", title: "No trail reports yet", message: "Your friends' adventures show up here.")
    }
    .padding()
    .background(Theme.background)
}
