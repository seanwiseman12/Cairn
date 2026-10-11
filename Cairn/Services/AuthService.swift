import Foundation
import Observation
import Supabase

/// Owns sign-in state. `@Observable` makes SwiftUI views refresh when `state` changes.
@Observable
@MainActor
final class AuthService {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID, email: String?)
    }

    private(set) var state: State = .loading

    /// Follows Supabase auth events (initial session, sign in, sign out, token refresh).
    /// Runs for the app's lifetime, started from RootView's `.task`.
    func listen() async {
        for await (_, session) in supabase.auth.authStateChanges {
            if let session, !session.isExpired {
                state = .signedIn(userID: session.user.id, email: session.user.email)
            } else {
                state = .signedOut
            }
        }
    }

    /// Returns true if the user is signed in right away. False means Supabase
    /// sent a confirmation email first (when "Confirm email" is on).
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await supabase.auth.signUp(email: email, password: password)
        return response.session != nil
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
