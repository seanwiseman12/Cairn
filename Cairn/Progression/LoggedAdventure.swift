import Foundation

/// What kind of adventure it was. Harder kinds earn more base XP.
enum AdventureType: String, CaseIterable, Codable, Sendable, Identifiable {
    case hike, summit, climb, ski, trek, expedition, volcano, canyon, other

    var id: Self { self }

    var label: String {
        switch self {
        case .hike: "Hike"
        case .summit: "Summit"
        case .climb: "Climb"
        case .ski: "Ski"
        case .trek: "Trek"
        case .expedition: "Expedition"
        case .volcano: "Volcano"
        case .canyon: "Canyon"
        case .other: "Adventure"
        }
    }

    var symbol: String {
        switch self {
        case .hike: "figure.hiking"
        case .summit: "mountain.2.fill"
        case .climb: "figure.climbing"
        case .ski: "figure.skiing.downhill"
        case .trek: "backpack.fill"
        case .expedition: "flag.fill"
        case .volcano: "flame.fill"
        case .canyon: "water.waves"
        case .other: "star.fill"
        }
    }
}

/// How hard it felt. Multiplies the effort XP, so a strenuous day counts for more.
enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case easy, moderate, hard, extreme

    var id: Self { self }

    var label: String { rawValue.capitalized }

    var multiplier: Double {
        switch self {
        case .easy: 1.0
        case .moderate: 1.25
        case .hard: 1.5
        case .extreme: 2.0
        }
    }
}

/// One logged adventure, with everything XP and badges need.
/// (The Supabase `adventures` table will hold the same fields in Phase 2.)
struct LoggedAdventure: Identifiable, Hashable, Sendable {
    var id = UUID()
    var type: AdventureType
    var title: String
    var date: Date
    var latitude: Double
    var longitude: Double
    /// The bundled peak's GeoNames id, when the log is on a known peak.
    var peakID: Int64?
    /// Height of the summit reached, in metres (for the high-altitude bonus).
    var summitElevation: Int?
    /// ISO country code, e.g. "US", from reverse geocoding.
    var countryCode: String?
    /// Two-letter US state code, e.g. "NY"; only for logs in the US.
    var usStateCode: String?
    var distanceMeters: Double?
    var elevationGainMeters: Double?
    var difficulty: Difficulty = .moderate
}
