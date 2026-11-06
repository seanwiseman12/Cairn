import Foundation

// MARK: - Rules

/// Every XP number in one place, so balancing the game means editing only this.
enum XPRules {
    // Effort: what you did.
    static func baseXP(for type: AdventureType) -> Int {
        switch type {
        case .other: 40
        case .hike, .ski: 100
        case .canyon: 120
        case .trek, .summit, .volcano: 150
        case .climb: 200
        case .expedition: 400
        }
    }
    /// +1 XP per this many metres climbed.
    static let metresPerXP = 10.0
    /// XP per kilometre covered.
    static let xpPerKilometre = 10.0
    /// Bonus for reaching a high summit: the highest band reached counts.
    static let altitudeBonuses: [(metres: Int, xp: Int)] = [(7000, 1000), (5000, 400), (3000, 150)]

    // Exploration: where you went.
    /// First adventure in a new country.
    static let newCountryXP = 500
    /// First adventure in a new US state.
    static let newUSStateXP = 150

    // Milestones: badges with an XP boost.
    static let countryMilestones: [(count: Int, xp: Int)] =
        [(3, 300), (5, 500), (10, 1000), (25, 2500), (50, 5000), (100, 10000)]
    static let usStateMilestones: [(count: Int, xp: Int)] = [(10, 500), (25, 1500), (50, 5000)]
}

// MARK: - Badges

/// A badge you can earn.
enum Badge: Hashable, Sendable, Identifiable {
    /// A passport stamp for adventuring in a country.
    case countryStamp(code: String)
    /// Adventures in this many countries.
    case countries(Int)
    /// Adventures in this many US states.
    case usStates(Int)
    /// Every peak on a list (e.g. the Adirondack 46ers).
    case peakList(id: String)

    var id: String {
        switch self {
        case let .countryStamp(code): "stamp-\(code)"
        case let .countries(count): "countries-\(count)"
        case let .usStates(count): "states-\(count)"
        case let .peakList(id): "list-\(id)"
        }
    }

    func title(lists: [PeakList]) -> String {
        switch self {
        case let .countryStamp(code): Self.countryName(code)
        case let .countries(count): "\(count) Countries"
        case let .usStates(count): count == 50 ? "All 50 States" : "\(count) States"
        case let .peakList(id): lists.first { $0.id == id }?.name ?? "Peak list"
        }
    }

    func detail(lists: [PeakList]) -> String {
        switch self {
        case .countryStamp: "Adventured here"
        case let .countries(count): "Adventures in \(count) countries"
        case let .usStates(count): "Adventures in \(count) US states"
        case let .peakList(id): lists.first { $0.id == id }?.detail ?? ""
        }
    }

    func symbol(lists: [PeakList]) -> String {
        switch self {
        case .countryStamp: "seal.fill"
        case .countries: "globe.europe.africa.fill"
        case .usStates: "flag.fill"
        case let .peakList(id): lists.first { $0.id == id }?.symbol ?? "mountain.2.fill"
        }
    }

    static func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// The country's flag emoji, e.g. "CH" → 🇨🇭.
    static func flag(_ code: String) -> String {
        code.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(127_397 + $0.value) }
            .map(String.init).joined()
    }
}

struct EarnedBadge: Identifiable, Hashable, Sendable {
    let badge: Badge
    let date: Date
    /// The adventure that unlocked it.
    let adventureID: UUID
    var id: String { badge.id }
}

// MARK: - XP breakdown

/// One line of an adventure's XP, e.g. "+500 · First adventure in Switzerland".
struct XPItem: Hashable, Sendable {
    enum Kind: Sendable { case effort, exploration, badge }
    let kind: Kind
    let label: String
    let xp: Int
}

struct XPBreakdown: Hashable, Sendable {
    var items: [XPItem] = []
    var total: Int { items.reduce(0) { $0 + $1.xp } }
}

// MARK: - Engine

/// Works out XP, level and badges from a user's adventures. It replays them in
/// date order, so "first adventure in a new country" and "finished the list"
/// go to the adventure that actually did it.
struct Progression: Sendable {
    let totalXP: Int
    let level: Level
    let breakdowns: [UUID: XPBreakdown]
    /// Newest first.
    let earnedBadges: [EarnedBadge]
    let countries: [String]
    let usStates: [String]
    /// Peaks climbed per list: list id → indexes into `PeakList.peaks`.
    let listProgress: [String: Set<Int>]
    let lists: [PeakList]

    static let empty = Progression(adventures: [], lists: [])

    init(adventures: [LoggedAdventure], lists: [PeakList]) {
        self.lists = lists
        var total = 0
        var breakdowns: [UUID: XPBreakdown] = [:]
        var earned: [EarnedBadge] = []
        var countries: [String] = []
        var states: [String] = []
        var listProgress: [String: Set<Int>] = [:]

        let ordered = adventures.enumerated()
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)

        for adventure in ordered {
            var breakdown = Self.effort(for: adventure)

            func earn(_ badge: Badge, xp: Int, label: String) {
                earned.append(EarnedBadge(badge: badge, date: adventure.date, adventureID: adventure.id))
                if xp > 0 { breakdown.items.append(XPItem(kind: .badge, label: label, xp: xp)) }
            }

            // New country: XP, a passport stamp, maybe a milestone badge.
            if let code = adventure.countryCode?.uppercased(), !code.isEmpty, !countries.contains(code) {
                countries.append(code)
                let name = Badge.countryName(code)
                breakdown.items.append(XPItem(kind: .exploration, label: "First adventure in \(name)",
                                              xp: XPRules.newCountryXP))
                earn(.countryStamp(code: code), xp: 0, label: "")
                if let milestone = XPRules.countryMilestones.first(where: { $0.count == countries.count }) {
                    earn(.countries(milestone.count), xp: milestone.xp, label: "\(milestone.count) countries badge")
                }
            }

            // New US state: a smaller boost, plus state milestones.
            if adventure.countryCode?.uppercased() == "US", let state = adventure.usStateCode?.uppercased(),
               !state.isEmpty, !states.contains(state) {
                states.append(state)
                breakdown.items.append(XPItem(kind: .exploration, label: "First adventure in \(state)",
                                              xp: XPRules.newUSStateXP))
                if let milestone = XPRules.usStateMilestones.first(where: { $0.count == states.count }) {
                    earn(.usStates(milestone.count), xp: milestone.xp, label: "\(milestone.count) states badge")
                }
            }

            // Peak lists: the log that completes a list earns its badge and bonus.
            for list in lists {
                guard let index = list.peakIndex(for: adventure) else { continue }
                var done = listProgress[list.id, default: []]
                let wasComplete = done.count == list.peaks.count
                done.insert(index)
                listProgress[list.id] = done
                if !wasComplete, done.count == list.peaks.count {
                    earn(.peakList(id: list.id), xp: list.bonusXP, label: "Completed the \(list.name)")
                }
            }

            breakdowns[adventure.id] = breakdown
            total += breakdown.total
        }

        totalXP = total
        level = Level(xp: total)
        self.breakdowns = breakdowns
        earnedBadges = earned.reversed()
        self.countries = countries
        usStates = states
        self.listProgress = listProgress
    }

    /// Effort XP: base for the type, plus climbing, distance and altitude, all
    /// scaled by difficulty. The multiplier shows as its own line.
    static func effort(for adventure: LoggedAdventure) -> XPBreakdown {
        var items = [XPItem(kind: .effort, label: adventure.type.label, xp: XPRules.baseXP(for: adventure.type))]
        if let gain = adventure.elevationGainMeters, gain >= XPRules.metresPerXP {
            items.append(XPItem(kind: .effort, label: "\(Int(gain)) m climbed",
                                xp: Int(gain / XPRules.metresPerXP)))
        }
        if let distance = adventure.distanceMeters, distance >= 100 {
            let km = distance / 1000
            items.append(XPItem(kind: .effort, label: "\(km.formatted(.number.precision(.fractionLength(0...1)))) km",
                                xp: Int((km * XPRules.xpPerKilometre).rounded())))
        }
        if let summit = adventure.summitElevation,
           let band = XPRules.altitudeBonuses.first(where: { summit >= $0.metres }) {
            items.append(XPItem(kind: .effort, label: "Above \(band.metres.formatted()) m", xp: band.xp))
        }
        let multiplier = adventure.difficulty.multiplier
        if multiplier > 1 {
            let subtotal = items.reduce(0) { $0 + $1.xp }
            let extra = Int((Double(subtotal) * (multiplier - 1)).rounded())
            items.append(XPItem(kind: .effort,
                                label: "\(adventure.difficulty.label) ×\(multiplier.formatted())", xp: extra))
        }
        return XPBreakdown(items: items)
    }

    // MARK: Badge shelf

    /// A badge for display: earned, or locked with progress toward it.
    struct BadgeStatus: Identifiable, Sendable {
        let badge: Badge
        let earned: EarnedBadge?
        /// e.g. (12, 46); nil for badges without steps.
        let progress: (done: Int, total: Int)?
        /// XP it gives when earned (0 for passport stamps).
        let rewardXP: Int
        var id: String { badge.id }
        var isEarned: Bool { earned != nil }
    }

    func status(of badge: Badge) -> BadgeStatus {
        let earned = earnedBadges.first { $0.badge == badge }
        switch badge {
        case .countryStamp:
            return BadgeStatus(badge: badge, earned: earned, progress: nil, rewardXP: 0)
        case let .countries(count):
            let xp = XPRules.countryMilestones.first { $0.count == count }?.xp ?? 0
            return BadgeStatus(badge: badge, earned: earned, progress: (min(countries.count, count), count), rewardXP: xp)
        case let .usStates(count):
            let xp = XPRules.usStateMilestones.first { $0.count == count }?.xp ?? 0
            return BadgeStatus(badge: badge, earned: earned, progress: (min(usStates.count, count), count), rewardXP: xp)
        case let .peakList(id):
            let list = lists.first { $0.id == id }
            return BadgeStatus(badge: badge, earned: earned,
                               progress: (listProgress[id]?.count ?? 0, list?.peaks.count ?? 0),
                               rewardXP: list?.bonusXP ?? 0)
        }
    }

    var peakListBadges: [BadgeStatus] { lists.map { status(of: .peakList(id: $0.id)) } }
    var countryMilestoneBadges: [BadgeStatus] { XPRules.countryMilestones.map { status(of: .countries($0.count)) } }
    var usStateMilestoneBadges: [BadgeStatus] { XPRules.usStateMilestones.map { status(of: .usStates($0.count)) } }
    /// One stamp per country visited, in the order they were first visited.
    var passportStamps: [BadgeStatus] { countries.map { status(of: .countryStamp(code: $0)) } }
}
