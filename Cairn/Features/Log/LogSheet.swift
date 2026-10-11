import SwiftUI

/// Opened by the + button. The three ways to log are laid out here; each one
/// gets wired up once the database exists (Phases 3 and 4).
struct LogSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                JournalHeader(kicker: "log a new", title: "Adventure")
                    .padding(.top, 20)

                LogOption(
                    icon: "photo.on.rectangle.angled",
                    title: "From a photo",
                    detail: "Place, date and nearby peak come straight from your photo.",
                    tint: Theme.rust,
                    isRecommended: true
                )
                LogOption(
                    icon: "magnifyingglass",
                    title: "Search a peak or place",
                    detail: "Any named peak on Earth, or anywhere on the map.",
                    tint: Theme.forest
                )
                LogOption(
                    icon: "mappin.and.ellipse",
                    title: "Drop a pin",
                    detail: "Long-press the globe to mark the spot.",
                    tint: Theme.sky
                )

                Text("Logging switches on once the database is set up.")
                    .font(.script(17, relativeTo: .footnote))
                    .foregroundStyle(Theme.groundText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

private struct LogOption: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    var isRecommended = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.script(23, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                    if isRecommended {
                        Text("Fastest").journalLabel()
                            .foregroundStyle(Theme.rust)
                    }
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.fadedInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.fadedInk)
        }
        .journalCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
