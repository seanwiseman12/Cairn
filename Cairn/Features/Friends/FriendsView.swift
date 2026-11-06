import SwiftUI

/// Friends tab: the feed and leaderboard share one screen. Built out in Phase 6.
struct FriendsView: View {
    private enum Section: String, CaseIterable {
        case feed = "Feed"
        case leaderboard = "Leaderboard"

        var symbol: String {
            switch self {
            case .feed: "newspaper.fill"
            case .leaderboard: "trophy.fill"
            }
        }
    }

    @State private var section: Section = DebugLaunch.sampleProgress ? .leaderboard : .feed

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(text: "Friends")
                    .padding(.top, 12)

                HStack(spacing: 10) {
                    ForEach(Section.allCases, id: \.self) { item in
                        Button {
                            withAnimation(.snappy) { section = item }
                        } label: {
                            Chip(title: item.rawValue, symbol: item.symbol, isSelected: section == item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                }

                switch section {
                case .feed:
                    EmptyStateCard(
                        symbol: "book.pages",
                        title: "No trail reports yet",
                        message: "When your friends log adventures, they show up here."
                    )
                case .leaderboard:
                    LeaderboardView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }
}

/// Ranked list of you and your friends by XP, countries or badges.
struct LeaderboardView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case xp = "XP", countries = "Countries", badges = "Badges"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .xp: "sparkles"
            case .countries: "globe.europe.africa.fill"
            case .badges: "rosette"
            }
        }
    }

    @Environment(ProgressStore.self) private var progress
    @State private var metric: Metric = .xp

    private var ranked: [LeaderboardEntry] {
        progress.leaderboard(you: "You").sorted { value($0) > value($1) || (value($0) == value($1) && $0.isYou) }
    }

    private func value(_ entry: LeaderboardEntry) -> Int {
        switch metric {
        case .xp: entry.xp
        case .countries: entry.countries
        case .badges: entry.badges
        }
    }

    private func valueText(_ entry: LeaderboardEntry) -> String {
        switch metric {
        case .xp: "\(entry.xp.formatted()) XP"
        case .countries: "\(entry.countries)"
        case .badges: "\(entry.badges)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(Metric.allCases) { item in
                    Button {
                        withAnimation(.snappy) { metric = item }
                    } label: {
                        Chip(title: item.rawValue, symbol: item.symbol, isSelected: metric == item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(metric == item ? .isSelected : [])
                }
            }

            if let place = ranked.firstIndex(where: \.isYou), ranked.count > 1 {
                placeBanner(place: place + 1)
            }

            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                    row(rank: index + 1, entry: entry)
                    if index < ranked.count - 1 {
                        Divider().overlay(Theme.border)
                    }
                }
            }
            .card(padding: 6)

            if progress.friends.isEmpty {
                EmptyStateCard(
                    symbol: "person.2",
                    title: "No rivals yet",
                    message: "Add friends to race for XP, countries and badges."
                )
            }
        }
    }

    /// "You're in 3rd place", like the reference's progress banner.
    private func placeBanner(place: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: place == 1 ? "crown.fill" : "trophy.fill")
                .font(.cairn(.headline))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("You're in \(place.formatted(.number.notation(.automatic)))\(ordinalSuffix(place)) place")
                    .font(.cairn(.headline))
                    .foregroundStyle(Theme.textPrimary)
                Text(place == 1 ? "Top of the pack. Keep it up!" : "Keep it up! Every summit counts.")
                    .font(.cairn(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.surfaceMuted, in: Capsule())
    }

    private func ordinalSuffix(_ n: Int) -> String {
        if (11...13).contains(n % 100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(.cairn(.footnote, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, alignment: .leading)
            Text(initials(entry.name))
                .font(.cairn(.subheadline, weight: .semibold))
                .foregroundStyle(entry.isYou ? Theme.onAccent : Theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(entry.isYou ? Theme.accent : Theme.surfaceMuted, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.cairn(.subheadline, weight: .semibold))
                    .foregroundStyle(entry.isYou ? Theme.accent : Theme.textPrimary)
                Text("\(entry.level.rank.title) · Lv \(entry.level.number)")
                    .font(.cairn(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Text(valueText(entry))
                .font(.cairn(.footnote, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(Theme.surfaceMuted, in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }
}
