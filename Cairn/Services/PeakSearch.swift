import Foundation
import SQLite3

/// A named mountain, peak, volcano, hill or range from the bundled peaks database.
struct Peak: Identifiable, Hashable, Sendable {
    enum Kind: Int, Sendable {
        case peak = 0, mountain, volcano, range, hill

        var label: String {
            switch self {
            case .peak: "Peak"
            case .mountain: "Mountain"
            case .volcano: "Volcano"
            case .range: "Range"
            case .hill: "Hill"
            }
        }

        var symbol: String {
            switch self {
            case .volcano: "flame"
            case .range: "mountain.2"
            case .hill: "triangle"
            case .peak, .mountain: "mountain.2.fill"
            }
        }
    }

    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    /// Metres above sea level, when known.
    let elevation: Int?
    /// ISO country code such as "NP"; empty when unknown.
    let countryCode: String
    let kind: Kind
}

/// Searches the bundled peaks database: every named peak, mountain, volcano,
/// hill and range in GeoNames (CC BY 4.0), built by tools/make_peaks.py into
/// Resources/Peaks/peaks.sqlite.
///
/// The database stores each name split into lowercase, accent-free words in a
/// `tokens` table, so "eve" finds "Mount Everest" and "matter" finds "Matterhorn".
/// Every query word must prefix-match some word of the name (or of one of its
/// alternate names). Results come most famous first: the database ranks each
/// mountain by elevation plus how many languages name it, so "Ben Nevis" finds
/// Scotland's before same-named hills elsewhere.
final class PeakSearch: @unchecked Sendable {
    static let shared = PeakSearch()

    // SQLite connections aren't thread-safe, so every query runs on this queue.
    private let queue = DispatchQueue(label: "PeakSearch")
    private var db: OpaquePointer?

    private init() {
        guard let url = Bundle.main.url(forResource: "peaks", withExtension: "sqlite") else {
            assertionFailure("peaks.sqlite is missing from the app bundle")
            return
        }
        // immutable=1: the bundle is read-only, so skip locking and journal checks.
        let uri = url.absoluteString + "?immutable=1"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) != SQLITE_OK {
            assertionFailure("Couldn't open peaks.sqlite")
            db = nil
        }
    }

    func search(_ text: String, limit: Int = 25) async -> [Peak] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.run(text, limit: limit))
            }
        }
    }

    /// One peak by its GeoNames id.
    func peak(id: Int64) async -> Peak? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.runPeak(id))
            }
        }
    }

    private func runPeak(_ id: Int64) -> Peak? {
        guard let db else { return nil }
        var statement: OpaquePointer?
        let sql = "SELECT id, name, lat, lon, ele, country, kind FROM peaks WHERE id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return peak(from: statement)
    }

    /// Reads a row of (id, name, lat, lon, ele, country, kind).
    private func peak(from statement: OpaquePointer?) -> Peak {
        Peak(
            id: sqlite3_column_int64(statement, 0),
            name: String(cString: sqlite3_column_text(statement, 1)),
            // Stored as degrees × 100,000 to keep the file small.
            latitude: Double(sqlite3_column_int(statement, 2)) / 100_000,
            longitude: Double(sqlite3_column_int(statement, 3)) / 100_000,
            elevation: sqlite3_column_type(statement, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 4)),
            countryCode: sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? "",
            kind: Peak.Kind(rawValue: Int(sqlite3_column_int(statement, 6))) ?? .peak
        )
    }

    /// The peak's Wikimedia Commons photo file name, if it has one
    /// (the `photos` table from tools/add_peak_photos.py).
    func photoFile(for id: Int64) async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.runPhotoFile(id))
            }
        }
    }

    private func runPhotoFile(_ id: Int64) -> String? {
        guard let db else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT file FROM photos WHERE peak_id = ?", -1, &statement, nil) == SQLITE_OK
        else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: text)
    }

    /// Lowercase, accent-free words: "Mönch Peak" → ["monch", "peak"].
    /// tools/make_peaks.py normalizes names the same way.
    static func words(in text: String) -> [String] {
        var folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        for (letter, spelling) in spellOut {
            folded = folded.replacingOccurrences(of: letter, with: spelling)
        }
        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Letters that don't split into "base letter + accent", so need spelling out
    /// (same list as SPELL_OUT in tools/make_peaks.py).
    private static let spellOut = ["ø": "o", "æ": "ae", "œ": "oe", "đ": "d", "ð": "d", "ł": "l",
                                   "ı": "i", "þ": "th", "ß": "ss"]

    private func run(_ text: String, limit: Int) -> [Peak] {
        guard let db else { return [] }
        let words = Array(Self.words(in: text).prefix(4))
        guard let first = words.first, first.count >= 2 || words.count > 1 else { return [] }

        // One "has a word starting with ..." condition per query word.
        let wordFilter = Array(repeating: "p.id IN (SELECT peak_id FROM tokens WHERE token >= ? AND token < ?)",
                               count: words.count)
            .joined(separator: " AND ")
        let sql = """
            SELECT p.id, p.name, p.lat, p.lon, p.ele, p.country, p.kind
            FROM peaks p
            WHERE \(wordFilter)
            ORDER BY p.rank DESC
            LIMIT ?
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        func bindPrefix(_ prefix: String) {
            sqlite3_bind_text(statement, index, prefix, -1, sqliteTransient)
            sqlite3_bind_text(statement, index + 1, prefix + Self.prefixEnd, -1, sqliteTransient)
            index += 2
        }
        words.forEach(bindPrefix)
        sqlite3_bind_int(statement, index, Int32(limit))

        var results: [Peak] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(peak(from: statement))
        }
        return results
    }

    /// Appended to a prefix to get the end of its range: every string starting
    /// with "eve" sorts between "eve" and "eve\u{10FFFF}".
    private static let prefixEnd = "\u{10FFFF}"
}

/// Tells SQLite to copy bound strings (the C macro SQLITE_TRANSIENT isn't visible to Swift).
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
