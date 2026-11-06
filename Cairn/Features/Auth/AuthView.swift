import SwiftUI

/// Email + password sign in and sign up.
/// Sign in with Apple comes later; it needs the paid Apple Developer account.
struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    CairnMark(size: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome to Cairn")
                            .font(.cairn(.headline))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Adventure\nAwaits")
                            .font(.cairn(size: 46, weight: .semibold, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Log every summit, trail and trek on Earth, and see them all on your globe.")
                            .font(.cairn(.body))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 48)

                VStack(alignment: .leading, spacing: 14) {
                    Text(isSignUp ? "Create your account" : "Sign in")
                        .font(.cairn(.title3, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password (at least 6 characters)", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if let message {
                        Text(message)
                            .font(.cairn(.footnote))
                            .foregroundStyle(Theme.danger)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView().tint(Theme.onForest)
                        } else {
                            Text(isSignUp ? "Create account" : "Sign in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isWorking || email.isEmpty || password.count < 6)
                    .padding(.top, 4)
                }
                .textFieldStyle(CairnFieldStyle())
                .card(padding: 20)

                Button(isSignUp ? "Have an account? Sign in" : "New here? Create an account") {
                    isSignUp.toggle()
                    message = nil
                }
                .font(.cairn(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)

                Button("Skip for now") {
                    auth.continueAsGuest()
                }
                .font(.cairn(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Explore Cairn without an account")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
    }

    private func submit() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            if isSignUp {
                let signedIn = try await auth.signUp(email: email, password: password)
                if !signedIn {
                    message = "Check your email to confirm your account, then sign in."
                    isSignUp = false
                }
            } else {
                try await auth.signIn(email: email, password: password)
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview {
    AuthView().environment(AuthService())
}
