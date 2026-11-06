import SwiftUI

/// App entry point. `@main` tells iOS to start here.
@main
struct CairnApp: App {
    // One shared AuthService for the whole app, passed down via the environment.
    @State private var auth = AuthService()
    // XP, level and badges, shared by every tab.
    @State private var progress = ProgressStore()
    // Planned adventures, saved on the phone.
    @State private var plans = PlanStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(progress)
                .environment(plans)
        }
    }
}
