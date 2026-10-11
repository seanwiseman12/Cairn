import SwiftUI

/// "You" tab: rank, passport stamps and account. Profile details come in Phase 5.
struct YouView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                JournalHeader(kicker: "the explorer", title: "You")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        CairnMark(size: 44)
                            .frame(width: 56, height: 56)
                            .background(Theme.ink.opacity(0.07), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trailhead")
                                .font(.script(30, relativeTo: .title))
                                .foregroundStyle(Theme.ink)
                            Text("Level 1 · 0 XP")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.fadedInk)
                        }
                    }
                    PencilProgressBar(progress: 0)
                    Text("Log your first adventure to start climbing the ranks.")
                        .font(.footnote)
                        .foregroundStyle(Theme.fadedInk)
                }
                .journalCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Passport stamps").journalLabel()
                    HStack {
                        EmptyStamp()
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    Text("Every new country you log earns a stamp.")
                        .font(.footnote)
                        .foregroundStyle(Theme.fadedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .journalCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Account").journalLabel()
                    if case let .signedIn(_, email) = auth.state {
                        Text(email ?? "—")
                            .foregroundStyle(Theme.ink)
                    }
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .foregroundStyle(Theme.rust)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .journalCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(ContourBackground())
    }
}
