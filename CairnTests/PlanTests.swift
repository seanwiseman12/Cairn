import Foundation
import Testing
@testable import Cairn

/// Planned adventures: ordering, saving, and XP estimates.
@MainActor
struct PlanTests {
    private func place(_ id: String, country: String? = "US", peakID: Int64? = nil, lat: Double = 0,
                       lon: Double = 0, elevation: Int? = nil) -> GlobeDestination {
        GlobeDestination(id: id, name: id, subtitle: "", latitude: lat, longitude: lon,
                         symbol: "mountain.2.fill", peakID: peakID, countryCode: country, elevation: elevation)
    }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + Double(n) * 86_400) }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("plans-\(UUID()).json")
    }

    @Test func datedPlansSortSoonestFirstAndSomedayKeepsOrder() {
        let store = PlanStore(fileURL: nil)
        store.save(PlannedAdventure(place: place("late"), type: .hike, targetDate: day(30)))
        store.save(PlannedAdventure(place: place("a"), type: .hike))
        store.save(PlannedAdventure(place: place("soon"), type: .hike, targetDate: day(2)))
        store.save(PlannedAdventure(place: place("b"), type: .hike))
        #expect(store.upcoming.map(\.place.id) == ["soon", "late"])
        #expect(store.someday.map(\.place.id) == ["a", "b"])
    }

    @Test func reorderingSomeday() {
        let store = PlanStore(fileURL: nil)
        for id in ["a", "b", "c"] { store.save(PlannedAdventure(place: place(id), type: .hike)) }
        store.moveSomeday(from: [2], to: 0)
        #expect(store.someday.map(\.place.id) == ["c", "a", "b"])
    }

    @Test func savesAndReloads() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PlanStore(fileURL: url)
        var plan = PlannedAdventure(place: place("rainier", elevation: 4392), type: .summit, targetDate: day(5),
                                    notes: "Book permits")
        store.save(plan)
        plan.notes = "Permits booked"
        store.save(plan) // same id: replaces, doesn't duplicate

        let reloaded = PlanStore(fileURL: url)
        #expect(reloaded.plans.count == 1)
        #expect(reloaded.plans.first?.notes == "Permits booked")
        #expect(reloaded.plans.first?.place.elevation == 4392)
        reloaded.remove(plan.id)
        #expect(PlanStore(fileURL: url).plans.isEmpty)
    }

    @Test func estimateIncludesNewCountryBonusOnlyWhenNew() {
        let visitedUS = Progression(adventures: [
            LoggedAdventure(type: .hike, title: "", date: day(0), latitude: 0, longitude: 0, countryCode: "US"),
        ], lists: [])
        let usPlan = PlannedAdventure(place: place("us", country: "US"), type: .hike)
        let chPlan = PlannedAdventure(place: place("ch", country: "CH"), type: .hike)
        // Hike 100 at Moderate ×1.25 = 125.
        #expect(visitedUS.estimate(for: usPlan).xp == 125)
        #expect(visitedUS.estimate(for: chPlan).xp == 125 + XPRules.newCountryXP)
        #expect(visitedUS.estimate(for: chPlan).isNewCountry)
    }

    @Test func estimateNotesPeakListProgress() {
        let list = PeakList(id: "two", name: "Test Two", region: "", detail: "", symbol: "", bonusXP: 1000, peaks: [
            .init(name: "Alpha", ids: [1], lat: 10, lon: 10, ele: 1000),
            .init(name: "Beta", ids: [2], lat: 20, lon: 20, ele: 1000),
        ])
        let none = Progression(adventures: [], lists: [list])
        let alphaPlan = PlannedAdventure(place: place("alpha", peakID: 1, lat: 10, lon: 10), type: .summit)
        #expect(none.estimate(for: alphaPlan).listNote == "1st of the Test Two")

        let didAlpha = Progression(adventures: [
            LoggedAdventure(type: .summit, title: "", date: day(0), latitude: 10, longitude: 10, peakID: 1),
        ], lists: [list])
        let betaPlan = PlannedAdventure(place: place("beta", peakID: 2, lat: 20, lon: 20), type: .summit)
        let estimate = didAlpha.estimate(for: betaPlan)
        #expect(estimate.listNote?.hasPrefix("Finishes the Test Two") == true)
        #expect(estimate.xp >= 1000)
    }
}
