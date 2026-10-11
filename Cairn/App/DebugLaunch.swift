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

    static var showAuth: Bool { flag("debugShowAuth") }
    static var showLogSheet: Bool { flag("debugShowLogSheet") }

    private static func flag(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }
}
