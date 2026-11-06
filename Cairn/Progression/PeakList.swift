import Foundation

/// A named group of peaks to complete, like the Adirondack 46ers. Climbing every
/// peak on a list earns its badge and a large XP bonus.
/// Lists live in Resources/PeakLists/peak-lists.json.
struct PeakList: Identifiable, Hashable, Sendable, Decodable {
    struct Peak: Hashable, Sendable, Decodable {
        let name: String
        /// GeoNames ids from the bundled peaks database; a log on any of them counts.
        let ids: [Int64]
        let lat: Double
        let lon: Double
        let ele: Int?
    }

    let id: String
    let name: String
    let region: String
    let detail: String
    let symbol: String
    let bonusXP: Int
    let peaks: [Peak]

    /// A log counts for a peak if it's on that peak, or within this distance of its
    /// summit (for logs dropped as pins, and peaks missing from GeoNames).
    static let matchRadiusMeters = 400.0

    /// Index of the list peak this adventure reached, if any.
    func peakIndex(for adventure: LoggedAdventure) -> Int? {
        if let peakID = adventure.peakID, let index = peaks.firstIndex(where: { $0.ids.contains(peakID) }) {
            return index
        }
        return peaks.firstIndex { peak in
            Self.distanceMeters(adventure.latitude, adventure.longitude, peak.lat, peak.lon) <= Self.matchRadiusMeters
        }
    }

    /// Great-circle distance (haversine).
    static func distanceMeters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }

    /// The lists bundled with the app.
    static let bundled: [PeakList] = {
        guard let url = Bundle.main.url(forResource: "peak-lists", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            assertionFailure("peak-lists.json is missing from the app bundle")
            return []
        }
        return decode(data)
    }()

    static func decode(_ data: Data) -> [PeakList] {
        struct File: Decodable { let lists: [PeakList] }
        return (try? JSONDecoder().decode(File.self, from: data).lists) ?? []
    }
}
