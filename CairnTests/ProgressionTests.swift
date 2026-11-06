import Foundation
import Testing
@testable import Cairn

/// XP, levels and badges (Cairn/Progression). Run with ⌘U in Xcode.
struct ProgressionTests {
    // MARK: Helpers

    private static let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ n: Int) -> Date { Self.start.addingTimeInterval(Double(n) * 86_400) }

    private func adventure(
        _ type: AdventureType = .hike, day n: Int = 0, country: String? = nil, state: String? = nil,
        lat: Double = 0, lon: Double = 0, peakID: Int64? = nil, summit: Int? = nil,
        km: Double? = nil, gain: Double? = nil, difficulty: Difficulty = .easy
    ) -> LoggedAdventure {
        LoggedAdventure(type: type, title: "Test", date: day(n), latitude: lat, longitude: lon, peakID: peakID,
                        summitElevation: summit, countryCode: country, usStateCode: state,
                        distanceMeters: km.map { $0 * 1000 }, elevationGainMeters: gain, difficulty: difficulty)
    }

    /// A two-peak list: one matched by GeoNames id, one only by position.
    private let twoPeaks = PeakList(
        id: "test", name: "Test Two", region: "Testland", detail: "Both peaks", symbol: "mountain.2.fill",
        bonusXP: 1000,
        peaks: [
            .init(name: "Alpha", ids: [111], lat: 44.0, lon: -74.0, ele: 1500),
            .init(name: "Beta", ids: [], lat: 44.1, lon: -74.1, ele: 1400),
        ])

    // MARK: Levels

    @Test func levelCurve() {
        #expect(Level(xp: 0).number == 1)
        #expect(Level(xp: 149).number == 1)
        #expect(Level(xp: 150).number == 2)
        #expect(Level(xp: 2_400).number == 5)
        #expect(Level(xp: 12_150).number == 10)
        #expect(Level.xpRequired(for: 30) == 126_150)
    }

    @Test func rankTitles() {
        #expect(Level(xp: 0).rank == .trailhead)
        #expect(Level(xp: 2_400).rank == .wanderer)
        #expect(Level(xp: 12_150).rank == .pathfinder)
        #expect(Level(xp: 400_000).rank == .legend)
        #expect(Rank.legend.next == nil)
    }

    @Test func levelProgressWithinLevel() {
        let level = Level(xp: 225) // level 2 runs 150..<600
        #expect(level.number == 2)
        #expect(level.xpIntoLevel == 75)
        #expect(level.xpForNextLevel == 450)
    }

    // MARK: Effort

    @Test func effortAddsTypeClimbDistanceAndDifficulty() {
        // Hike 100 + 1,000 m (100) + 10 km (100) = 300, Hard ×1.5 adds 150.
        let breakdown = Progression.effort(for: adventure(.hike, km: 10, gain: 1000, difficulty: .hard))
        #expect(breakdown.total == 450)
    }

    @Test func harderTypesEarnMore() {
        let hike = Progression.effort(for: adventure(.hike)).total
        let climb = Progression.effort(for: adventure(.climb)).total
        let expedition = Progression.effort(for: adventure(.expedition)).total
        #expect(hike < climb && climb < expedition)
    }

    @Test func highSummitBonusUsesHighestBand() {
        let base = XPRules.baseXP(for: .summit)
        #expect(Progression.effort(for: adventure(.summit, summit: 2_900)).total == base)
        #expect(Progression.effort(for: adventure(.summit, summit: 3_200)).total == base + 150)
        #expect(Progression.effort(for: adventure(.summit, summit: 5_895)).total == base + 400)
        #expect(Progression.effort(for: adventure(.summit, summit: 8_848)).total == base + 1000)
    }

    // MARK: Exploration

    @Test func newCountryBonusOnlyOnFirstVisit() {
        let first = adventure(day: 1, country: "CH")
        let second = adventure(day: 2, country: "CH")
        let result = Progression(adventures: [second, first], lists: [])
        let base = XPRules.baseXP(for: .hike)
        #expect(result.breakdowns[first.id]?.total == base + XPRules.newCountryXP)
        #expect(result.breakdowns[second.id]?.total == base)
        #expect(result.countries == ["CH"])
        #expect(result.passportStamps.count == 1)
    }

    @Test func usStateBonusOnlyInsideTheUS() {
        let ny = adventure(day: 1, country: "US", state: "NY")
        let nyAgain = adventure(day: 2, country: "US", state: "NY")
        let notUS = adventure(day: 3, country: "CA", state: "ON")
        let result = Progression(adventures: [ny, nyAgain, notUS], lists: [])
        #expect(result.usStates == ["NY"])
        let base = XPRules.baseXP(for: .hike)
        #expect(result.breakdowns[ny.id]?.total == base + XPRules.newCountryXP + XPRules.newUSStateXP)
        #expect(result.breakdowns[nyAgain.id]?.total == base)
    }

    @Test func countryMilestoneBadgesAndXP() {
        let codes = ["US", "CA", "MX", "FR", "IT"]
        let logs = codes.enumerated().map { adventure(day: $0.offset, country: $0.element) }
        let result = Progression(adventures: logs, lists: [])
        #expect(result.status(of: .countries(3)).isEarned)
        #expect(result.status(of: .countries(5)).isEarned)
        #expect(!result.status(of: .countries(10)).isEarned)
        #expect(result.status(of: .countries(10)).progress?.done == 5)
        // The third country's log carries the 3-countries boost.
        let third = result.breakdowns[logs[2].id]
        #expect(third?.items.contains { $0.kind == .badge && $0.xp == 300 } == true)
    }

    @Test func tenStatesBadge() {
        let states = ["NY", "VT", "NH", "ME", "MA", "CT", "RI", "NJ", "PA", "CO"]
        let logs = states.enumerated().map { adventure(day: $0.offset, country: "US", state: $0.element) }
        let result = Progression(adventures: logs, lists: [])
        #expect(result.status(of: .usStates(10)).isEarned)
        #expect(!result.status(of: .usStates(25)).isEarned)
    }

    // MARK: Peak lists

    @Test func finishingAListEarnsBadgeAndBonusOnce() {
        let alpha = adventure(.summit, day: 1, peakID: 111)
        let beta = adventure(.summit, day: 2, lat: 44.1005, lon: -74.1004) // ~60 m from Beta's summit
        let betaAgain = adventure(.summit, day: 3, lat: 44.1, lon: -74.1)
        let result = Progression(adventures: [alpha, beta, betaAgain], lists: [twoPeaks])
        #expect(result.status(of: .peakList(id: "test")).isEarned)
        #expect(result.listProgress["test"]?.count == 2)
        #expect(result.breakdowns[beta.id]?.items.contains { $0.kind == .badge && $0.xp == 1000 } == true)
        #expect(result.breakdowns[betaAgain.id]?.items.contains { $0.kind == .badge } == false)
    }

    @Test func listCompletionGoesToTheChronologicallyLastPeak() {
        // Logged out of order: Beta was climbed first, Alpha completes the list.
        let alpha = adventure(.summit, day: 5, peakID: 111)
        let beta = adventure(.summit, day: 1, lat: 44.1, lon: -74.1)
        let result = Progression(adventures: [alpha, beta], lists: [twoPeaks])
        #expect(result.earnedBadges.first { $0.badge == .peakList(id: "test") }?.adventureID == alpha.id)
    }

    @Test func farAwayLogDoesNotCount() {
        let near = adventure(.summit, day: 1, lat: 44.104, lon: -74.1) // ~450 m away
        let result = Progression(adventures: [near], lists: [twoPeaks])
        #expect(result.listProgress["test"] == nil)
    }

    @Test func bundledListsAreComplete() throws {
        let url = try #require(Bundle.main.url(forResource: "peak-lists", withExtension: "json"))
        let lists = PeakList.decode(try Data(contentsOf: url))
        #expect(lists.first { $0.id == "adk46" }?.peaks.count == 46)
        #expect(lists.first { $0.id == "seven-summits" }?.peaks.count == 7)
    }
}
