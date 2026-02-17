//
//  LoginView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showRegister = false
    @State private var showResetAlert = false
    
    @State private var resetResultMessage: String?
    @State private var showResetResultAlert = false

    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationStack {
            ZStack {
                darkBackground.ignoresSafeArea()
                
                RadialGradient(
                    colors: [wickedGreen.opacity(0.3), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                ).ignoresSafeArea()
                
                RadialGradient(
                    colors: [glindaPink.opacity(0.15), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 500
                ).ignoresSafeArea()

                VStack(spacing: 22) {
                    Text("Welcome")
                        .font(.system(.largeTitle, design: .serif))
                        .fontWeight(.bold)
                        .foregroundStyle(wickedGreen)
                        .padding(.bottom, 10)
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(glindaPink.opacity(0.8))
                            .frame(width: 20) // Stała szerokość dla wyrównania
                        
                        TextField("Email", text: $email)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .tint(wickedGreen) // Kolor kursora
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(glindaPink.opacity(0.8))
                            .frame(width: 20)
                        
                        SecureField("Password", text: $password)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .tint(wickedGreen)
                    }
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    // --- WYŚWIETLANIE BŁĘDU LOGOWANIA ---
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .padding(.top, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // --- PRZYCISK LOGOWANIA (Główny) ---
                    Button("Log in") {
                        print("CLICK REGISTERED - Starting login.")
                        Task {
                            do {
                                errorMessage = nil
                                guard !email.isEmpty, !password.isEmpty else {
                                    errorMessage = "Fill in the Email and Password fields."
                                    return
                                }
                                try await authManager.signIn(email: email, password: password)
                            } catch {
                                errorMessage = error.localizedDescription
                                print("ERROR Logging in: \(error.localizedDescription)")
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(darkBackground)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(wickedGreen)
                    .clipShape(Capsule())
                    .padding(.top, 10)
                    
                    Button("Forgot your password?") {
                        showResetAlert = true
                    }
                    .foregroundStyle(glindaPink)
                    .padding(.top)
                    
                    Spacer()
                    
                    Button("Create a new account") {
                        showRegister = true
                    }
                    .foregroundStyle(glindaPink)
                    
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .preferredColorScheme(.dark)
            }
            .alert("Password reset", isPresented: $showResetAlert) {
                Button("Send password reset link") {
                    Task {
                        guard !email.isEmpty else {
                            resetResultMessage = "Please enter your email address in the email field first."
                            showResetResultAlert = true
                            return
                        }
                        
                        do {
                            try await resetPassword()
                            resetResultMessage = "A password reset link has been sent to \(email)."
                            showResetResultAlert = true
                            
                        } catch {
                            resetResultMessage = error.localizedDescription
                            showResetResultAlert = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A password reset link will be sent to the email address you provided in the Email field.")
            }
            .alert("Password Reset", isPresented: $showResetResultAlert) {
                Button("OK") { }
            } message: {
                Text(resetResultMessage ?? "An unknown error occurred.")
            }
        }
    }
    
    private func resetPassword() async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
