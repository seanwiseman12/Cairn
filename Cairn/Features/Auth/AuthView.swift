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
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Cairn")
                    .font(.largeTitle.bold())
                Text("Log every adventure on Earth.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            .textFieldStyle(.roundedBorder)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Create account" : "Sign in")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking || email.isEmpty || password.count < 6)

            Button(isSignUp ? "Have an account? Sign in" : "New here? Create an account") {
                isSignUp.toggle()
                message = nil
            }
            .font(.footnote)

            Spacer()
        }
        .padding(24)
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
