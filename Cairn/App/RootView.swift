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
                    .background(Theme.background)
            case .signedOut:
                AuthView()
            case .signedIn:
                if DebugLaunch.showAuth { AuthView() } else { MainTabView() }
            case .guest:
                MainTabView()
            }
        }
        .tint(Theme.accent)
        .font(.cairn(.body))
        // The whole app uses the dark look, so system controls (keyboard,
        // sheets, status bar) match it.
        .preferredColorScheme(.dark)
        .animation(.default, value: auth.state)
        .task { await auth.listen() }
    }
}

enum AppTab: String, Hashable {
    case globe, plans, friends, you
}

/// Tabs: Globe · Plans · Friends · You, switched by a floating bar that also
/// holds the + (log an adventure) button.
struct MainTabView: View {
    @State private var router = AppRouter()
    @State private var showLogSheet = false

    var body: some View {
        TabView(selection: $router.tab) {
            GlobeView()
                .tag(AppTab.globe)
                .modifier(LeavesRoomForTabBar())
            PlansView()
                .tag(AppTab.plans)
                .modifier(LeavesRoomForTabBar())
            FriendsView()
                .tag(AppTab.friends)
                .modifier(LeavesRoomForTabBar())
            YouView()
                .tag(AppTab.you)
                .modifier(LeavesRoomForTabBar())
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(selection: $router.tab) { showLogSheet = true }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
        }
        .sheet(isPresented: $showLogSheet) {
            LogSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
        .environment(router)
    }
}

/// Hides the system tab bar and keeps each tab's content clear of the floating one.
private struct LeavesRoomForTabBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: FloatingTabBar.height + 8)
            }
    }
}

/// Dark capsule tab bar. The current tab is a white-outlined pill with its
/// name; the white circle in the middle logs an adventure.
private struct FloatingTabBar: View {
    /// 48-point buttons plus 8 points of padding above and below.
    static let height: CGFloat = 64

    @Binding var selection: AppTab
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            item(.globe, symbol: "globe.americas", label: "Globe")
            item(.plans, symbol: "bookmark", label: "Plans")
            Button(action: onLog) {
                Image(systemName: "plus")
                    .font(.cairn(.title3, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 48, height: 48)
                    .background(Theme.accent, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Log an adventure")
            item(.friends, symbol: "person.2", label: "Friends")
            item(.you, symbol: "person.crop.circle", label: "You")
        }
        .padding(8)
        .background(Theme.surface.opacity(0.92), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .animation(.snappy(duration: 0.25), value: selection)
    }

    private func item(_ tab: AppTab, symbol: String, label: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.cairn(.body, weight: .semibold))
                if isSelected {
                    Text(label)
                        .font(.cairn(.subheadline, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.onForestMuted)
            .padding(.horizontal, isSelected ? 14 : 0)
            .frame(minWidth: 48, minHeight: 48)
            .background {
                if isSelected {
                    Capsule().fill(Theme.accent.opacity(0.08))
                    Capsule().strokeBorder(Theme.accent, lineWidth: 1.2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: isSelected ? nil : .infinity)
        .layoutPriority(isSelected ? 1 : 0)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
