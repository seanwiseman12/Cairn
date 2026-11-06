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
        /// Browsing without an account ("Skip for now"). Nothing is saved to Supabase.
        case guest
    }

    private(set) var state: State = .loading

    /// Remembers "Skip for now" between launches until the user signs in or leaves guest mode.
    private static let guestKey = "isGuest"
    private var isGuest: Bool {
        get { UserDefaults.standard.bool(forKey: Self.guestKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.guestKey) }
    }

    /// Follows Supabase auth events (initial session, sign in, sign out, token refresh).
    /// Runs for the app's lifetime, started from RootView's `.task`.
    func listen() async {
        for await (_, session) in supabase.auth.authStateChanges {
            if let session, !session.isExpired {
                isGuest = false
                state = .signedIn(userID: session.user.id, email: session.user.email)
            } else {
                state = isGuest ? .guest : .signedOut
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

    /// "Skip for now": go straight to the app without an account.
    func continueAsGuest() {
        isGuest = true
        state = .guest
    }

    /// Leaves guest mode and returns to the sign-in screen.
    func exitGuest() {
        isGuest = false
        state = .signedOut
    }
}
