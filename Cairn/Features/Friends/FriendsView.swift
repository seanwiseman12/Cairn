import SwiftUI

/// Friends tab: the feed and leaderboard share one screen. Built out in Phase 6.
struct FriendsView: View {
    fileprivate enum Section: String, CaseIterable {
        case feed = "Feed"
        case leaderboard = "Leaderboard"
    }

    @State private var section: Section = .feed

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                JournalHeader(kicker: "out on the trail with", title: "Friends")

                SectionSwitch(selection: $section)

                switch section {
                case .feed:
                    JournalEmptyState(
                        icon: "book.pages",
                        title: "No trail reports yet",
                        message: "When your friends log adventures, their pages show up here."
                    )
                case .leaderboard:
                    JournalEmptyState(
                        icon: "trophy",
                        title: "No rivals yet",
                        message: "Add friends to race for XP, countries and metres climbed."
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(ContourBackground())
    }
}

/// Feed | Leaderboard switch in the display face: the chosen side is a cream tab.
private struct SectionSwitch: View {
    @Binding var selection: FriendsView.Section

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FriendsView.Section.allCases, id: \.self) { section in
                let isSelected = section == selection
                Button {
                    withAnimation(.snappy) { selection = section }
                } label: {
                    Text(section.rawValue.uppercased())
                        .font(.display(22, relativeTo: .headline))
                        .tracking(1.2)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.cream)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.contourLine.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
