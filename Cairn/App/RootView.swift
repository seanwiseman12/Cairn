import SwiftUI

/// The "auth gate": shows sign-in when logged out and the main tabs when logged in.
struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ContourBackground())
            case .signedOut:
                AuthView()
            case .signedIn:
                if DebugLaunch.showAuth { AuthView() } else { MainTabView() }
            }
        }
        .tint(Theme.forest)
        .animation(.default, value: auth.state)
        .task { await auth.listen() }
    }
}

enum AppTab: String, Hashable {
    case globe, friends, you
}

/// Tabs: Globe · Friends · You. Logging lives behind the + button on the Globe.
struct MainTabView: View {
    @State private var tab: AppTab = DebugLaunch.initialTab ?? .globe

    var body: some View {
        TabView(selection: $tab) {
            GlobeView()
                .tabItem { Label("Globe", systemImage: "globe.americas.fill") }
                .tag(AppTab.globe)
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(AppTab.friends)
            YouView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(AppTab.you)
        }
    }
}
