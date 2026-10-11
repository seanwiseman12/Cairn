import SwiftUI

/// The Cairn logo: a stack of stones with a rust capstone.
struct CairnMark: View {
    var size: CGFloat = 64
    var color: Color = Theme.ink

    var body: some View {
        VStack(spacing: size * 0.04) {
            Capsule().fill(Theme.rust)
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

/// Screen title in the style of the reference: a small italic "kicker" line
/// above a big cream display word with a worn print texture.
struct JournalHeader: View {
    var kicker: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: -6) {
            if let kicker {
                Text(kicker)
                    .font(.script(26, relativeTo: .title3))
                    .foregroundStyle(Theme.cream)
            }
            Text(title.uppercased())
                .font(.display(68, relativeTo: .largeTitle))
                .foregroundStyle(Theme.cream)
                .speckled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Level progress drawn like a pencil stroke filling a ruled line.
struct PencilProgressBar: View {
    /// 0...1
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .stroke(Theme.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Capsule()
                    .fill(Theme.forest)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Level progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// A rubber-stamp badge for a visited country.
struct StampBadge: View {
    let country: String
    let year: String
    var color: Color = Theme.rust
    var rotation: Double = -6

    var body: some View {
        VStack(spacing: 0) {
            Text(country.uppercased())
                .font(.display(26, relativeTo: .headline))
                .tracking(1.5)
            Text(year)
                .font(.script(15, relativeTo: .caption))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 2.5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color.opacity(0.55), lineWidth: 1).padding(4))
        .speckled(Theme.card.opacity(0.7))
        .rotationEffect(.degrees(rotation))
    }
}

/// Dashed outline where a stamp will go once something is logged.
struct EmptyStamp: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("FIRST STAMP")
                .font(.display(24, relativeTo: .headline))
                .tracking(1.5)
            Text("awaits")
                .font(.script(16, relativeTo: .caption))
        }
        .foregroundStyle(Theme.fadedInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.fadedInk, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .rotationEffect(.degrees(-4))
    }
}

/// Centered icon + italic title + message for screens with nothing in them yet.
struct JournalEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.forest)
            Text(title)
                .font(.script(26, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.fadedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .journalCard(padding: 28)
    }
}

#Preview {
    VStack(spacing: 24) {
        JournalHeader(kicker: "the explorer", title: "You")
        CairnMark()
        StampBadge(country: "Nepal", year: "2026")
        StampBadge(country: "Peru", year: "2025", color: Theme.forest, rotation: 5)
        EmptyStamp()
        PencilProgressBar(progress: 0.4)
    }
    .padding()
    .background(ContourBackground())
}
