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
            VStack(spacing: 28) {
                VStack(spacing: -10) {
                    Text("the field journal")
                        .font(.script(32, relativeTo: .title))
                    Text("CAIRN")
                        .font(.display(150, relativeTo: .largeTitle))
                        .tracking(2)
                        .speckled()
                    Text("for every adventure")
                        .font(.script(32, relativeTo: .title))
                }
                .foregroundStyle(Theme.cream)
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .padding(.top, 56)

                VStack(alignment: .leading, spacing: 14) {
                    Text(isSignUp ? "Start your journal" : "Welcome back")
                        .font(.script(28, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email").journalLabel()
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").journalLabel()
                        SecureField("At least 6 characters", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.rust)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView().tint(Theme.cream)
                        } else {
                            Text(isSignUp ? "Create account" : "Sign in")
                        }
                    }
                    .buttonStyle(JournalButtonStyle())
                    .disabled(isWorking || email.isEmpty || password.count < 6)
                    .padding(.top, 4)
                }
                .textFieldStyle(JournalFieldStyle())
                .journalCard(padding: 20)

                Button(isSignUp ? "Have an account? Sign in" : "New here? Create an account") {
                    isSignUp.toggle()
                    message = nil
                }
                .font(.script(22, relativeTo: .body))
                .foregroundStyle(Theme.cream)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ContourBackground())
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
