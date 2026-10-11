import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Feed", systemImage: "hammer", description: Text("Coming in Phase 6."))
                .navigationTitle("Feed")
        }
    }
}
