import SwiftUI

/// A peak-list challenge, like the Adirondack 46ers: progress toward the badge
/// and the XP bonus it gives.
struct PeakListCard: View {
    let list: PeakList
    let status: Progression.BadgeStatus

    private var done: Int { status.progress?.done ?? 0 }
    private var total: Int { status.progress?.total ?? list.peaks.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: list.symbol)
                    .font(.cairn(.title3))
                    .foregroundStyle(status.isEarned ? Theme.onAccent : Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(status.isEarned ? Theme.accent : Theme.accent.opacity(0.1), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(status.isEarned ? 0 : 0.45), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.cairn(.headline))
                        .foregroundStyle(Theme.textPrimary)
                    Text(list.region)
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(status.isEarned ? "Earned" : "+\(list.bonusXP.formatted()) XP")
                    .font(.cairn(.caption, weight: .bold))
                    .foregroundStyle(status.isEarned ? Theme.onAccent : Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(status.isEarned ? Theme.accent : Theme.accent.opacity(0.1), in: Capsule())
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                LevelProgressBar(progress: total == 0 ? 0 : Double(done) / Double(total))
                Text("\(done) of \(total) peaks")
                    .font(.cairn(.footnote).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// A round medal for a milestone (3 countries, 10 states…). Locked medals are
/// dashed and grey, with progress under them.
struct MilestoneMedal: View {
    let status: Progression.BadgeStatus
    let symbol: String
    /// Big number on the medal, e.g. "5".
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(status.isEarned ? Theme.accent : Theme.surface)
                Circle()
                    .strokeBorder(status.isEarned ? Theme.accent.opacity(0.35) : Theme.textSecondary.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.5, dash: status.isEarned ? [] : [4, 4]))
                    .padding(status.isEarned ? -5 : 0)
                VStack(spacing: 0) {
                    Image(systemName: symbol)
                        .font(.cairn(.caption2, weight: .semibold))
                    Text(value)
                        .font(.cairn(.title2, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(status.isEarned ? Theme.onAccent : Theme.textSecondary)
            }
            .frame(width: 64, height: 64)
            .padding(5)

            VStack(spacing: 1) {
                Text(caption)
                    .font(.cairn(.caption, weight: .semibold))
                    .foregroundStyle(status.isEarned ? Theme.textPrimary : Theme.textSecondary)
                if let progress = status.progress, !status.isEarned {
                    Text("\(progress.done)/\(progress.total)")
                        .font(.cairn(.caption2).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                } else if status.rewardXP > 0 {
                    Text("+\(status.rewardXP.formatted()) XP")
                        .font(.cairn(.caption2))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(caption), \(status.isEarned ? "earned" : "locked")")
    }
}

/// A passport stamp for a country: the flag inside a white ring, slightly tilted
/// like a real stamp.
struct PassportStamp: View {
    let code: String
    let date: Date?

    var body: some View {
        VStack(spacing: 6) {
            Text(Badge.flag(code))
                .font(.system(size: 30))
                .frame(width: 60, height: 60)
                .background(Theme.surfaceMuted, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).padding(-4))
                .rotationEffect(.degrees(Double(abs(code.hashValue % 13)) - 6))
            Text(Badge.countryName(code))
                .font(.cairn(.caption, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let date {
                Text(date.formatted(.dateTime.year()))
                    .font(.cairn(.caption2))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// How XP is earned, straight from `XPRules`, so it always matches the game.
struct XPRulesCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                    Text("How XP works")
                        .font(.cairn(.headline))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.cairn(.footnote, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    group("Effort", [
                        "Hike or ski +\(XPRules.baseXP(for: .hike)) · Summit or trek +\(XPRules.baseXP(for: .summit)) · Climb +\(XPRules.baseXP(for: .climb)) · Expedition +\(XPRules.baseXP(for: .expedition))",
                        "+1 per \(Int(XPRules.metresPerXP)) m climbed · +\(Int(XPRules.xpPerKilometre)) per km",
                        "Summits above 3,000 / 5,000 / 7,000 m: +150 / +400 / +1,000",
                        "Harder days count for more: Moderate ×1.25 · Hard ×1.5 · Extreme ×2",
                    ])
                    group("Exploration", [
                        "First adventure in a new country +\(XPRules.newCountryXP) and a passport stamp",
                        "First adventure in a new US state +\(XPRules.newUSStateXP)",
                    ])
                    group("Badges", [
                        "Countries: " + XPRules.countryMilestones.map { "\($0.count) (+\($0.xp.formatted()))" }.joined(separator: " · "),
                        "US states: " + XPRules.usStateMilestones.map { "\($0.count) (+\($0.xp.formatted()))" }.joined(separator: " · "),
                        "Finish a peak list for a big bonus, like +4,600 for the Adirondack 46",
                    ])
                }
                .transition(.opacity)
            }
        }
        .card()
    }

    private func group(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.cairn(.caption2, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.accent)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.cairn(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
