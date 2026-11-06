import Foundation

/// Debug-only launch options so screens can be opened directly for screenshots, e.g.
/// `xcrun simctl launch booted com.cairnapp.Cairn -debugTab you -debugShowAuth YES`.
/// Always off in release builds.
enum DebugLaunch {
    static var initialTab: AppTab? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugTab").flatMap(AppTab.init(rawValue:))
        #else
        nil
        #endif
    }

    /// Starting globe position and zoom, e.g. `-debugGlobeZoom 6 -debugGlobeLat 46 -debugGlobeLon 9`.
    static var globeZoom: Double? { number("debugGlobeZoom") }
    static var globeLat: Double? { number("debugGlobeLat") }
    static var globeLon: Double? { number("debugGlobeLon") }

    /// Globe search typed in at launch, e.g. `-debugSearch everest`; add
    /// `-debugPickFirst YES` to also pick the first mountain.
    static var searchQuery: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugSearch")
        #else
        nil
        #endif
    }
    static var pickFirstResult: Bool { flag("debugPickFirst") }

    static var showAuth: Bool { flag("debugShowAuth") }
    /// Open the home screen on a chosen mountain's photo instead of a random
    /// one, by GeoNames id: `-debugBackdrop 5868589` (Denali).
    static var backdropPeakID: Int64? { number("debugBackdrop").map { Int64($0) } }
    /// Load sample adventures and friends to preview XP, badges and the
    /// leaderboard: `-debugSampleProgress YES`.
    static var sampleProgress: Bool { flag("debugSampleProgress") }
    static var showLogSheet: Bool { flag("debugShowLogSheet") }

    private static func number(_ key: String) -> Double? {
        #if DEBUG
        UserDefaults.standard.object(forKey: key) == nil ? nil : UserDefaults.standard.double(forKey: key)
        #else
        nil
        #endif
    }

    private static func flag(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }
}
