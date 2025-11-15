//
//  LoginView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // Pobieramy AuthManager z Environment Object
    @Environment(AuthManager.self) private var authManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showRegister = false
    @State private var showResetAlert = false
    
    // --- POPRAWKA: Stany dla alertu wyników resetowania ---
    @State private var resetResultMessage: String?
    @State private var showResetResultAlert = false

    // --- WICKED STYLE: Paleta kolorów (bez zmian) ---
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1) // Lekko jaśniejsze tło

    var body: some View {
        NavigationStack {
            // --- WICKED GLASS: Tło z gradientem ---
            ZStack {
                // To tło będzie widoczne "przez" szkło
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

                
                // --- WICKED GLASS: "Szklana" karta logowania ---
                VStack(spacing: 22) { // Zwiększony odstęp
                    Text("Welcome")
                        .font(.system(.largeTitle, design: .serif))
                        .fontWeight(.bold)
                        .foregroundStyle(wickedGreen)
                        .padding(.bottom, 10)
                    
                    // --- WICKED GLASS: Pola tekstowe w stylu "frosted" ---
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(glindaPink.opacity(0.8))
                            .frame(width: 20) // Stała szerokość dla wyrównania
                        
                        TextField("Email", text: $email)
                            .padding(.vertical, 12) // Większa wysokość
                            .foregroundStyle(.white)
                            .tint(wickedGreen) // Kolor kursora
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.1)) // Lekki "frost"
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
                    .background(Color.white.opacity(0.1)) // Lekki "frost"
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
                                // Czyścimy stary błąd przed próbą logowania
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
                    .foregroundStyle(darkBackground) // Ciemny tekst na zielonym
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(wickedGreen)
                    .clipShape(Capsule())
                    .padding(.top, 10)
                    
                    // --- RESET HASŁA ---
                    Button("Forgot your password?") {
                        showResetAlert = true
                    }
                    .foregroundStyle(glindaPink)
                    .padding(.top)
                    
                    Spacer()
                    
                    // --- PRZEJŚCIE DO REJESTRACJI ---
                    Button("Create a new account") {
                        showRegister = true
                    }
                    .foregroundStyle(glindaPink)
                    
                }
                .padding(30) // Duży wewnętrzny padding dla "karty"
                // --- WICKED GLASS: Modyfikatory "szkła" ---
                .background(.ultraThinMaterial) // Efekt szkła!
                .cornerRadius(25) // Zaokrąglone rogi
                .overlay(
                    // Subtelna ramka, aby "złapać" światło
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20) // Odstęp "karty" od krawędzi ekranu
                
            }
            .navigationBarHidden(true) // Ukrywamy pasek nawigacji
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .preferredColorScheme(.dark)
            }
            // --- POPRAWKA: Alert #1 (Pytanie o reset) ---
            .alert("Password reset", isPresented: $showResetAlert) {
                Button("Send password reset link") {
                    Task {
                        // --- POPRAWKA: Logika walidacji przeniesiona tutaj ---
                        guard !email.isEmpty else {
                            resetResultMessage = "Please enter your email address in the email field first."
                            showResetResultAlert = true
                            return
                        }
                        
                        do {
                            try await resetPassword()
                            // Sukces: Ustaw komunikat sukcesu
                            resetResultMessage = "A password reset link has been sent to \(email)."
                            showResetResultAlert = true
                            
                        } catch {
                            // Błąd: Ustaw komunikat błędu
                            resetResultMessage = error.localizedDescription
                            showResetResultAlert = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A password reset link will be sent to the email address you provided in the Email field.")
            }
            // --- POPRAWKA: Alert #2 (Wynik operacji) ---
            .alert("Password Reset", isPresented: $showResetResultAlert) {
                Button("OK") { }
            } message: {
                Text(resetResultMessage ?? "An unknown error occurred.")
            }
        }
    }
    
    // Logika resetu hasła (bez zmian)
    private func resetPassword() async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
