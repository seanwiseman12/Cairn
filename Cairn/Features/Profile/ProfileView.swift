import SwiftUI

/// Placeholder profile. The full profile (username, avatar, level) comes in Phase 2+.
struct ProfileView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        NavigationStack {
            List {
                if case let .signedIn(_, email) = auth.state {
                    LabeledContent("Signed in as", value: email ?? "—")
                }
                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
