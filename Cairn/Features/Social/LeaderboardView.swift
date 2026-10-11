import SwiftUI

struct LeaderboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Leaderboard", systemImage: "hammer", description: Text("Coming in Phase 6."))
                .navigationTitle("Leaderboard")
        }
    }
}
