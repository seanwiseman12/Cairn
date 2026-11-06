import Foundation

/// Levels and rank titles from total XP.
///
/// Reaching level L takes 150 × (L − 1)² XP in total, so each level needs a
/// little more than the last: level 2 at 150 XP, 5 at 2,400, 10 at 12,150,
/// 20 at 54,150, 30 at 126,150, 50 at 360,150.
struct Level: Equatable, Sendable {
    let number: Int
    let totalXP: Int

    init(xp: Int) {
        totalXP = max(0, xp)
        number = Int((Double(totalXP) / Self.xpScale).squareRoot()) + 1
    }

    static let xpScale = 150.0

    /// Total XP needed to reach `level`.
    static func xpRequired(for level: Int) -> Int {
        Int(xpScale * Double((level - 1) * (level - 1)))
    }

    var xpIntoLevel: Int { totalXP - Self.xpRequired(for: number) }
    var xpForNextLevel: Int { Self.xpRequired(for: number + 1) - Self.xpRequired(for: number) }
    /// 0...1 through the current level.
    var progress: Double { Double(xpIntoLevel) / Double(xpForNextLevel) }

    var rank: Rank { Rank.forLevel(number) }
}

/// Rank titles, each covering a band of levels.
enum Rank: Int, CaseIterable, Sendable {
    case trailhead, wanderer, pathfinder, mountaineer, explorer, legend

    var title: String {
        switch self {
        case .trailhead: "Trailhead"
        case .wanderer: "Wanderer"
        case .pathfinder: "Pathfinder"
        case .mountaineer: "Mountaineer"
        case .explorer: "Explorer"
        case .legend: "Legend"
        }
    }

    /// The first level with this rank.
    var firstLevel: Int {
        switch self {
        case .trailhead: 1
        case .wanderer: 5
        case .pathfinder: 10
        case .mountaineer: 20
        case .explorer: 30
        case .legend: 50
        }
    }

    var next: Rank? { Rank(rawValue: rawValue + 1) }

    static func forLevel(_ level: Int) -> Rank {
        allCases.last { level >= $0.firstLevel } ?? .trailhead
    }
}
