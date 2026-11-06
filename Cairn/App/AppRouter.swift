import Observation

/// Which tab is showing, plus requests from one tab to another, e.g. the
/// Plans tab asking the Globe to fly to a plan's place.
@Observable
@MainActor
final class AppRouter {
    var tab: AppTab = DebugLaunch.initialTab ?? .globe
    /// A place the Globe tab should fly to; it clears this once handled.
    var focusRequest: GlobeDestination?
    /// Ask the Globe tab to open search; it clears this once handled.
    var searchRequest = false

    func showOnGlobe(_ place: GlobeDestination) {
        tab = .globe
        focusRequest = place
    }

    func startSearch() {
        tab = .globe
        searchRequest = true
    }
}
