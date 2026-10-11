import SwiftUI

/// The "auth gate": shows sign-in when logged out and the main tabs when logged in.
struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                AuthView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.default, value: auth.state)
        .task { await auth.listen() }
    }
}

/// Tabs: Globe · Log · Feed · Leaderboard · Profile.
/// Most are placeholders until their phase is built.
struct MainTabView: View {
    var body: some View {
        TabView {
            GlobeView().tabItem { Label("Globe", systemImage: "globe.americas.fill") }
            LogAdventureView().tabItem { Label("Log", systemImage: "plus.circle.fill") }
            FeedView().tabItem { Label("Feed", systemImage: "person.2.fill") }
            LeaderboardView().tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
