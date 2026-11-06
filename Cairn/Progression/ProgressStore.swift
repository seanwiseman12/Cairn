import Foundation
import Observation

/// The signed-in explorer's adventures and the XP, level and badges they add up
/// to, shared by the Globe, Friends and You tabs.
///
/// Adventures arrive with logging (Phases 3 and 4) and friends with Phase 6.
/// Until then it's empty, except in debug builds launched with
/// `-debugSampleProgress YES`, which load sample data to preview the screens.
@Observable
@MainActor
final class ProgressStore {
    private(set) var adventures: [LoggedAdventure] = []
    private(set) var progression = Progression.empty
    /// Friends for the leaderboard (sample data only for now).
    private(set) var friends: [LeaderboardEntry] = []

    let lists = PeakList.bundled

    init() {
        if DebugLaunch.sampleProgress {
            adventures = SampleProgress.adventures
            friends = SampleProgress.friends
        }
        recompute()
    }

    func add(_ adventure: LoggedAdventure) {
        adventures.append(adventure)
        recompute()
    }

    private func recompute() {
        progression = Progression(adventures: adventures, lists: lists)
    }

    /// You plus friends, for the leaderboard.
    func leaderboard(you name: String) -> [LeaderboardEntry] {
        let me = LeaderboardEntry(
            id: "me", name: name, isYou: true,
            xp: progression.totalXP,
            countries: progression.countries.count,
            badges: progression.earnedBadges.filter { if case .countryStamp = $0.badge { false } else { true } }.count
        )
        return [me] + friends
    }
}

/// One row of the leaderboard.
struct LeaderboardEntry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var isYou = false
    let xp: Int
    let countries: Int
    /// Badges other than passport stamps.
    let badges: Int

    var level: Level { Level(xp: xp) }
}

/// Debug-only sample data for previewing XP, badges and the leaderboard.
enum SampleProgress {
    static var adventures: [LoggedAdventure] {
        let lists = PeakList.bundled
        var result: [LoggedAdventure] = []
        var day = Calendar.current.date(byAdding: .year, value: -2, to: .now) ?? .now
        func next() -> Date {
            day = Calendar.current.date(byAdding: .day, value: 9, to: day) ?? day
            return day
        }

        // 12 of the Adirondack 46 (New York).
        if let adk = lists.first(where: { $0.id == "adk46" }) {
            for peak in adk.peaks.prefix(12) {
                result.append(LoggedAdventure(
                    type: .summit, title: peak.name, date: next(), latitude: peak.lat, longitude: peak.lon,
                    peakID: peak.ids.first, summitElevation: peak.ele, countryCode: "US", usStateCode: "NY",
                    distanceMeters: 22_000, elevationGainMeters: 1_100, difficulty: .hard))
            }
        }
        result += [
            LoggedAdventure(type: .ski, title: "Vail back bowls", date: next(), latitude: 39.6061, longitude: -106.3550,
                            countryCode: "US", usStateCode: "CO", distanceMeters: 18_000, difficulty: .moderate),
            LoggedAdventure(type: .hike, title: "Franconia Ridge", date: next(), latitude: 44.1606, longitude: -71.6440,
                            countryCode: "US", usStateCode: "NH", distanceMeters: 14_500, elevationGainMeters: 1_160,
                            difficulty: .hard),
            LoggedAdventure(type: .climb, title: "Cathedral Peak", date: next(), latitude: 37.8475, longitude: -119.4053,
                            countryCode: "US", usStateCode: "CA", elevationGainMeters: 650, difficulty: .hard),
            LoggedAdventure(type: .hike, title: "Hörnli Hut", date: next(), latitude: 45.9822, longitude: 7.6750,
                            countryCode: "CH", distanceMeters: 10_000, elevationGainMeters: 700, difficulty: .moderate),
            LoggedAdventure(type: .trek, title: "Kilimanjaro, Machame Route", date: next(), latitude: -3.0758,
                            longitude: 37.3533, peakID: 157452, summitElevation: 5895, countryCode: "TZ",
                            distanceMeters: 62_000, elevationGainMeters: 4_000, difficulty: .extreme),
            LoggedAdventure(type: .hike, title: "Fimmvörðuháls", date: next(), latitude: 63.6297, longitude: -19.4500,
                            countryCode: "IS", distanceMeters: 25_000, elevationGainMeters: 1_000, difficulty: .hard),
            LoggedAdventure(type: .summit, title: "Mount Fuji", date: next(), latitude: 35.3606, longitude: 138.7274,
                            summitElevation: 3776, countryCode: "JP", distanceMeters: 15_000,
                            elevationGainMeters: 1_400, difficulty: .hard),
        ]
        return result
    }

    static let friends: [LeaderboardEntry] = [
        LeaderboardEntry(id: "s1", name: "Maya Lindqvist", xp: 31_800, countries: 14, badges: 4),
        LeaderboardEntry(id: "s2", name: "Theo Okafor", xp: 18_250, countries: 6, badges: 3),
        LeaderboardEntry(id: "s3", name: "Priya Raman", xp: 9_400, countries: 9, badges: 2),
        LeaderboardEntry(id: "s4", name: "Sam Whitaker", xp: 4_100, countries: 2, badges: 0),
        LeaderboardEntry(id: "s5", name: "Ines Duarte", xp: 1_350, countries: 3, badges: 1),
    ]
}
