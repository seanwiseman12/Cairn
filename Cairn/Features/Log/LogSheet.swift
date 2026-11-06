import SwiftUI

/// Opened by the + button. The three ways to log are laid out here; each one
/// gets wired up once the database exists (Phases 3 and 4).
struct LogSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    ScreenTitle(text: "New Adventure")
                    Text("Pick the quickest way in. We'll fill in the rest.")
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 28)

                FeaturedLogOption(
                    symbol: "photo.on.rectangle.angled",
                    title: "From a photo",
                    detail: "Place, date and nearby peak come straight from your photo."
                )
                LogOption(
                    symbol: "magnifyingglass",
                    title: "Search a peak or place",
                    detail: "Any named peak on Earth, or anywhere on the map."
                )
                LogOption(
                    symbol: "mappin.and.ellipse",
                    title: "Drop a pin",
                    detail: "Mark the exact spot on a map."
                )

                Text("Logging switches on once the database is set up.")
                    .font(.cairn(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

/// The recommended option as a forest-green card, like the reference's
/// "Himalayan Sunrise Trek" card.
private struct FeaturedLogOption: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol)
                .font(.cairn(.title2))
                .foregroundStyle(Theme.accent)
                .frame(width: 56, height: 56)
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 6) {
                Text("Fastest")
                    .font(.cairn(.caption, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.accent, in: Capsule())
                Text(title)
                    .font(.cairn(.title3, weight: .bold))
                    .foregroundStyle(Theme.onForest)
                Text(detail)
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.onForestMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.cairn(.subheadline, weight: .bold))
                .foregroundStyle(Theme.onForest)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.15), in: Circle())
        }
        .forestCard(padding: 20)
        .accessibilityElement(children: .combine)
    }
}

/// A white option card with an icon tile and an arrow button.
private struct LogOption: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.cairn(.title3))
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.cairn(.headline))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.cairn(.subheadline, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.surfaceMuted, in: Circle())
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
