//
//  SettingsView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 20/11/2025.
//

import SwiftUI
import Observation
import FirebaseAuth

// Enum dla dostępnych motywów
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    // Konwertuje na preferowany schemat kolorów dla SwiftUI
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct SettingsView: View {
    // --- ŚRODOWISKA ---
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(StorageManager.self) private var storageManager
    
    // --- LOKALNY STAN ---
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    @State private var deleteInProgress = false
    @State private var errorDeleting = false
    
    // --- USTAWIANIA APLIKACJI (Simulacja przechowywania w UserDefaults) ---
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @State private var selectedLanguage: String = "Polski" // Zastąp to systemem lokalizacji
    
    // --- BODY ---
    var body: some View {
        List {
            // MARK: - PERSONALIZACJA
            Section(header: Text("Personalization").font(.caption).bold()) {
                
                // --- Motyw ---
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                
                // --- Język (MOCKUP) ---
                HStack {
                    Text("Language")
                    Spacer()
                    // W prawdziwej aplikacji to by wymagało głębszej implementacji
                    Text(selectedLanguage)
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    // Możesz tutaj otworzyć widok wyboru języka
                }
                
                // --- Jednostki miary (SUGESTIA) ---
                Toggle("Imperial units (lb, ft)", isOn: .constant(false))
                    .disabled(true) // Wymagałoby implementacji logiki
            }
            
            // MARK: - ZARZĄDZANIE DANYMI (SUGESTIA)
            Section(header: Text("Data Management").font(.caption).bold()) {
                
                // --- Reset Wody (SUGESTIA) ---
                Button(action: {
                    // Wymagałoby implementacji WaterManager.resetWaterHistory()
                }) {
                    HStack {
                        Label("Reset water history", systemImage: "drop.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                }
                
                // --- Przejdź do edycji profilu (SUGESTIA) ---
                NavigationLink(destination: EditProfileDetailsView()) { // Zakładamy istnienie tego widoku
                    Label("Edit profile details", systemImage: "person.text.rectangle")
                }
            }
            
            // MARK: - KONTO
            Section(header: Text("Account").font(.caption).bold()) {
                
                // --- Wylogowanie ---
                Button(action: { showingLogoutAlert = true }) {
                    HStack {
                        Label("Logout", systemImage: "door.right.hand.open")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                
                // --- Usuwanie Konta ---
                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Label("Delete account", systemImage: "trash")
                            .foregroundStyle(.red)
                        Spacer()
                        if deleteInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(deleteInProgress)
            }
        }
        .navigationTitle("Settings")
        // Stosowanie wybranego motywu
        .preferredColorScheme(selectedTheme.colorScheme)
        
        // MARK: - ALERTY I AKCJE
        
        // Alert potwierdzający wylogowanie
        .alert("Confirm Logout", isPresented: $showingLogoutAlert) {
            Button("Logout", role: .destructive) {
                try? authManager.signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to log out?")
        }
        
        // Alert potwierdzający usunięcie konta
        .alert("Confirm Account Deletion", isPresented: $showingDeleteAlert) {
            Button("Delete Permanently", role: .destructive) {
                Task { await handleDeleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deleting your account will permanently remove all your data, including profile, recipes, and water logs. This action cannot be undone.")
        }
        
        // Alert błędu
        .alert("Error", isPresented: $errorDeleting) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("An unexpected error occurred while deleting the account. Please try again later.")
        }
    }
    
    // MARK: - LOGIKA USUWANIA
    private func handleDeleteAccount() async {
        guard !deleteInProgress else { return }
        deleteInProgress = true
        errorDeleting = false
        
        do {
            // Używamy koordynatora z AuthManagera
            try await authManager.deleteUserAndData(
                profileManager: profileManager,
                recipeManager: recipeManager,
                storageManager: storageManager
            )
            // Jeśli sukces, UI zostanie automatycznie zaktualizowane do AuthView
        } catch {
            print("SettingsView: Failed to delete account: \(error.localizedDescription)")
            errorDeleting = true
        }
        deleteInProgress = false
    }
}

// MARK: - STUB VIEWS (Do zastąpienia przez docelowe widoki)

// Musisz zaimplementować ten widok, aby pozwolić użytkownikowi na zmianę danych profilowych (wagę, aktywność)
struct EditProfileDetailsView: View {
    var body: some View {
        Text("Profile details editing view")
            .navigationTitle("Edit Profile")
    }
}
