import SwiftUI

/// "You" tab: rank and level, stats, badges (peak lists, milestones and
/// passport stamps), how XP works, and account. Profile details come in Phase 5.
struct YouView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ProgressStore.self) private var progress

    private var progression: Progression { progress.progression }
    private var level: Level { progression.level }

    private var email: String? {
        if case let .signedIn(_, email) = auth.state { return email }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Text(String(email?.first ?? "C").uppercased())
                        .font(.cairn(.title2, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 56, height: 56)
                        .background(Theme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.state == .guest ? "Guest Explorer" : "Explorer")
                            .font(.cairn(.title2, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if let email {
                            Text(email)
                                .font(.cairn(.subheadline))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.top, 12)

                rankCard

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StatChip(symbol: "globe.europe.africa.fill",
                                 text: "\(progression.countries.count) countries")
                        StatChip(symbol: "flag.fill", text: "\(progression.usStates.count) US states")
                        StatChip(symbol: "mountain.2.fill", text: "\(summitCount) summits")
                        StatChip(symbol: "arrow.up.right", text: metresClimbed)
                    }
                }
                .scrollClipDisabled()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Peak lists")
                    ForEach(progress.lists) { list in
                        PeakListCard(list: list, status: progression.status(of: .peakList(id: list.id)))
                    }
                }

                milestones

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Passport")
                    if progression.passportStamps.isEmpty {
                        emptyPassport
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 18) {
                            ForEach(progression.passportStamps) { stamp in
                                if case let .countryStamp(code) = stamp.badge {
                                    PassportStamp(code: code, date: stamp.earned?.date)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                XPRulesCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Account")
                    if auth.state == .guest {
                        Button {
                            auth.exitGuest()
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign in or create an account")
                                        .font(.cairn(.headline))
                                    Text("You're browsing as a guest.")
                                        .font(.cairn(.subheadline))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                            }
                            .foregroundStyle(Theme.accent)
                            .card()
                        }
                    } else {
                        Button(role: .destructive) {
                            Task { await auth.signOut() }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign out")
                                    .font(.cairn(.headline))
                                Spacer()
                            }
                            .foregroundStyle(Theme.danger)
                            .card()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var summitCount: Int {
        progress.adventures.filter { $0.type == .summit || $0.summitElevation != nil }.count
    }

    private var metresClimbed: String {
        let total = progress.adventures.compactMap(\.elevationGainMeters).reduce(0, +)
        return Measurement(value: total, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
            + " climbed"
    }

    /// Country and US-state milestone medals, each row scrolling sideways.
    private var milestones: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Milestones")
            medalRow(title: "Countries", statuses: progression.countryMilestoneBadges,
                     symbol: "globe.europe.africa.fill", caption: "countries")
            medalRow(title: "US states", statuses: progression.usStateMilestoneBadges,
                     symbol: "flag.fill", caption: "states")
        }
    }

    private func medalRow(title: String, statuses: [Progression.BadgeStatus], symbol: String,
                          caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.cairn(.caption2, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(statuses) { status in
                        MilestoneMedal(status: status, symbol: symbol,
                                       value: "\(status.progress?.total ?? 0)", caption: caption)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var emptyPassport: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.fill")
                .font(.cairn(.title3))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle().strokeBorder(Theme.textSecondary.opacity(0.6),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Your first stamp awaits")
                    .font(.cairn(.headline))
                    .foregroundStyle(Theme.textPrimary)
                Text("Every new country you adventure in earns a stamp and +\(XPRules.newCountryXP) XP.")
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    /// Raised rank card: rank title, level, total XP and progress to the next level.
    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "mountain.2.fill")
                    .font(.cairn(.title3))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rank.title)
                        .font(.cairn(.title2, weight: .bold))
                        .foregroundStyle(Theme.onForest)
                        .lineLimit(1)
                    Text("Level \(level.number) · \(level.totalXP.formatted()) XP")
                        .font(.cairn(.subheadline).monospacedDigit())
                        .foregroundStyle(Theme.onForestMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if let next = level.rank.next {
                Text("Next rank: \(next.title) at level \(next.firstLevel)")
                    .font(.cairn(.caption, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent, in: Capsule())
            }
            LevelProgressBar(progress: level.progress, onForest: true)
            Text(progress.adventures.isEmpty
                 ? "Log your first adventure to start climbing the ranks."
                 : "\((level.xpForNextLevel - level.xpIntoLevel).formatted()) XP to level \(level.number + 1)")
                .font(.cairn(.footnote))
                .foregroundStyle(Theme.onForestMuted)
        }
        .forestCard(padding: 20)
    }
}
