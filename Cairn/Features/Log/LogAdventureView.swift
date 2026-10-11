import SwiftUI

struct LogAdventureView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Log", systemImage: "hammer", description: Text("Coming in Phase 3."))
                .navigationTitle("Log")
        }
    }
}
