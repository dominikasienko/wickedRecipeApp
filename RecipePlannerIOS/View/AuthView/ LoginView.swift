//
//  LoginView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    private enum Field: Hashable {
        case email
        case password
    }

    @Environment(AuthManager.self) private var authManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: LocalizedStringKey?
    @State private var showRegister = false
    @State private var showResetAlert = false
    @State private var isSocialAuthInProgress = false

    @State private var resetResultMessage: LocalizedStringKey?
    @State private var showResetResultAlert = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ZStack {
                LoginAuthBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        card
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .alert(AppLocalization.key( "Password reset"), isPresented: $showResetAlert) {
                Button(AppLocalization.key( "Send password reset link")) {
                    Task {
                        guard !email.isEmpty else {
                            resetResultMessage = AppLocalization.key( "Please enter your email address in the email field first.")
                            showResetResultAlert = true
                            return
                        }

                        do {
                            try await resetPassword()
                            resetResultMessage = AppLocalization.key("A password reset link has been sent to \(email).")
                            showResetResultAlert = true
                        } catch {
                            resetResultMessage = AppLocalization.key("An unknown error occurred.")
                            showResetResultAlert = true
                        }
                    }
                }
                Button(AppLocalization.key( "Cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalization.key( "A password reset link will be sent to the email address you provided in the Email field."))
            }
            .alert(AppLocalization.key( "Password Reset"), isPresented: $showResetResultAlert) {
                Button(AppLocalization.key( "OK")) {}
            } message: {
                Text(resetResultMessage ?? AppLocalization.key( "An unknown error occurred."))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("AppStoreIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 10, y: 4)

            Text(AppLocalization.key( "Welcome"))
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(AppLocalization.key( "Log in"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.75))
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            loginField(icon: "envelope.fill") {
                TextField(AppLocalization.key( "Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }
                    .foregroundStyle(.white)
            }

            loginField(icon: "lock.fill") {
                SecureField(AppLocalization.key( "Password"), text: $password)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(login)
                    .foregroundStyle(.white)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            Button(action: login) {
                Text(AppLocalization.key( "Log in"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Color.darkBackground)
                    .background(Color.wickedGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSocialAuthInProgress)
            .keyboardShortcut(.defaultAction)

            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                Text(AppLocalization.key( "Continue with Google"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
            }

            Button(action: signInWithGoogle) {
                HStack(spacing: 12) {
                    LoginGoogleIcon()

                    Text(AppLocalization.key( "Continue with Google"))
                        .font(.headline.weight(.semibold))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialAuthInProgress)

            PrivacyPolicyNotice()

            Button(AppLocalization.key( "Forgot your password?")) {
                showResetAlert = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.glindaPink)

            Button(AppLocalization.key( "Create a new account")) {
                showRegister = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.top, 4)
        }
        .padding(22)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .onAppear {
            if focusedField == nil {
                focusedField = .email
            }
        }
    }

    private func loginField<Content: View>(
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.glindaPink)
                .frame(width: 20)

            content()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .tint(Color.wickedGreen)
    }

    private func login() {
        Task {
            do {
                errorMessage = nil
                guard !email.isEmpty, !password.isEmpty else {
                    errorMessage = AppLocalization.key( "Fill in the Email and Password fields.")
                    return
                }
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = AppLocalization.key("An unknown error occurred.")
            }
        }
    }

    private func resetPassword() async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    private func signInWithGoogle() {
        Task {
            isSocialAuthInProgress = true
            errorMessage = nil
            defer { isSocialAuthInProgress = false }

            do {
                try await authManager.signInWithGoogle()
            } catch {
                errorMessage = AppLocalization.key("An unknown error occurred.")
            }
        }
    }
}

private struct LoginAuthBackground: View {
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            LinearGradient(
                colors: [Color.black, Color.darkBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.wickedGreen.opacity(0.36), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.glindaPink.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
        }
    }
}

private struct LoginGoogleIcon: View {
    var body: some View {
        let glyph = Text("G")
            .font(.system(size: 18, weight: .bold, design: .rounded))

        glyph
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 66.0 / 255.0, green: 133.0 / 255.0, blue: 244.0 / 255.0),
                        Color(red: 219.0 / 255.0, green: 68.0 / 255.0, blue: 55.0 / 255.0),
                        Color(red: 244.0 / 255.0, green: 180.0 / 255.0, blue: 0),
                        Color(red: 15.0 / 255.0, green: 157.0 / 255.0, blue: 88.0 / 255.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}
