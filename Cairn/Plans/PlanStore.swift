import Foundation
import Observation

/// Something you want to do next: a place from search, what you'll do there,
/// when (or "someday"), and notes.
struct PlannedAdventure: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var place: GlobeDestination
    var type: AdventureType
    /// Nil means "someday".
    var targetDate: Date?
    var notes: String = ""
    var createdAt = Date()
}

/// The explorer's plans, saved as JSON on the phone (Application Support/plans.json)
/// so they survive restarts and work for guests. They move to Supabase with the
/// database phase.
///
/// Order matters for "Someday" plans: you can drag them into the order you want
/// to do them. Dated plans always sort by date.
@Observable
@MainActor
final class PlanStore {
    private(set) var plans: [PlannedAdventure] = []
    private let fileURL: URL?

    /// - Parameter fileURL: where to save; nil keeps plans in memory only.
    init(fileURL: URL? = PlanStore.defaultFileURL) {
        if DebugLaunch.sampleProgress {
            // Debug previews: sample plans, never written to disk.
            self.fileURL = nil
            plans = SamplePlans.plans
            return
        }
        self.fileURL = fileURL
        load()
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("plans.json")
    }

    /// Dated plans, soonest first.
    var upcoming: [PlannedAdventure] {
        plans.filter { $0.targetDate != nil }.sorted { $0.targetDate! < $1.targetDate! }
    }

    /// Undated plans, in the order you arranged them.
    var someday: [PlannedAdventure] {
        plans.filter { $0.targetDate == nil }
    }

    func plan(forPlace placeID: String) -> PlannedAdventure? {
        plans.first { $0.place.id == placeID }
    }

    /// Adds a new plan or replaces the one with the same id.
    func save(_ plan: PlannedAdventure) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        persist()
    }

    func remove(_ id: PlannedAdventure.ID) {
        plans.removeAll { $0.id == id }
        persist()
    }

    /// Reorders the "Someday" plans (indexes are within `someday`).
    func moveSomeday(from source: IndexSet, to destination: Int) {
        var reordered = someday
        reordered.move(fromOffsets: source, toOffset: destination)
        plans = plans.filter { $0.targetDate != nil } + reordered
        persist()
    }

    // MARK: Saving

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        plans = (try? JSONDecoder().decode([PlannedAdventure].self, from: data)) ?? []
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(plans).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Couldn't save plans: \(error)")
        }
    }
}

// MARK: - XP estimate

/// What a plan is worth if you go: estimated XP, and whether it ticks off a
/// peak on a list you're working on.
struct PlanEstimate: Equatable, Sendable {
    let xp: Int
    let isNewCountry: Bool
    /// e.g. "13th of the Adirondack 46ers".
    let listNote: String?
}

extension Progression {
    /// Estimates a plan's XP at Moderate difficulty: effort, plus the new-country
    /// bonus if you haven't adventured there yet. Distance and climbing aren't
    /// known until you go, so the real number is usually higher.
    func estimate(for plan: PlannedAdventure) -> PlanEstimate {
        let adventure = LoggedAdventure(
            type: plan.type, title: plan.place.name, date: .now,
            latitude: plan.place.latitude, longitude: plan.place.longitude,
            peakID: plan.place.peakID, summitElevation: plan.place.elevation,
            countryCode: plan.place.countryCode, difficulty: .moderate)
        var xp = Progression.effort(for: adventure).total
        let isNewCountry = plan.place.countryCode.map { !countries.contains($0.uppercased()) } ?? false
        if isNewCountry { xp += XPRules.newCountryXP }

        var listNote: String?
        for list in lists {
            guard let index = list.peakIndex(for: adventure) else { continue }
            let done = listProgress[list.id] ?? []
            guard !done.contains(index) else { continue }
            let nth = done.count + 1
            listNote = nth == list.peaks.count
                ? "Finishes the \(list.name)! +\(list.bonusXP.formatted()) XP"
                : "\(nth.formatted(.number))\(Self.ordinalSuffix(nth)) of the \(list.name)"
            if nth == list.peaks.count { xp += list.bonusXP }
            break
        }
        return PlanEstimate(xp: xp, isNewCountry: isNewCountry, listNote: listNote)
    }

    static func ordinalSuffix(_ n: Int) -> String {
        if (11...13).contains(n % 100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Debug samples

/// Debug-only sample plans (with `-debugSampleProgress YES`).
enum SamplePlans {
    static var plans: [PlannedAdventure] {
        func days(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: .now) ?? .now }
        return [
            PlannedAdventure(
                place: GlobeDestination(id: "peak-5128820", name: "Nippletop", subtitle: "1,393 m · United States",
                                        latitude: 44.08922, longitude: -73.81597, symbol: "mountain.2.fill",
                                        peakID: 5128820, countryCode: "US", elevation: 1393),
                type: .summit, targetDate: days(12), notes: "Via Elk Pass, back over Dial"),
            PlannedAdventure(
                place: GlobeDestination(id: "peak-2659729", name: "Matterhorn", subtitle: "4,478 m · Switzerland",
                                        latitude: 45.97639, longitude: 7.65861, symbol: "mountain.2.fill",
                                        peakID: 2659729, countryCode: "CH", elevation: 4478),
                type: .climb, targetDate: days(96), notes: "Hörnli Ridge with a guide. Book the hut in March."),
            PlannedAdventure(
                place: GlobeDestination(id: "peak-5807840", name: "Mount Rainier", subtitle: "4,392 m · United States",
                                        latitude: 46.85278, longitude: -121.76028, symbol: "flame",
                                        peakID: 5807840, countryCode: "US", elevation: 4392),
                type: .summit, notes: "Disappointment Cleaver route"),
            PlannedAdventure(
                place: GlobeDestination(id: "peak-2192136", name: "Aoraki / Mount Cook", subtitle: "3,724 m · New Zealand",
                                        latitude: -43.59472, longitude: 170.14194, symbol: "mountain.2.fill",
                                        peakID: 2192136, countryCode: "NZ", elevation: 3724),
                type: .trek, notes: "Hooker Valley track, then Mueller Hut"),
            PlannedAdventure(
                place: GlobeDestination(id: "peak-5731780", name: "Mount Hood", subtitle: "3,425 m · United States",
                                        latitude: 45.37361, longitude: -121.69583, symbol: "flame",
                                        peakID: 5731780, countryCode: "US", elevation: 3425),
                type: .ski, notes: "Spring corn on the Palmer"),
        ]
    }
}
