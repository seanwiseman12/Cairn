import SwiftUI

/// App entry point. `@main` tells iOS to start here.
@main
struct CairnApp: App {
    // One shared AuthService for the whole app, passed down via the environment.
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
