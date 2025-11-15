//
//  AuthView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import FirebaseAuth
import Observation

// AuthView.swift
struct AuthView: View {
    // --- Menedżery statyczne (pobierane ze środowiska) ---
    // Zostały przekazane przez RecipePlannerIOSApp.swift za pomocą .environment()
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(RecipeManager.self) private var recipeManager
    
    // --- Menedżery zależne od userId (tworzone dynamicznie) ---
    // Muszą być przechowywane w stanie lokalnym, aby mogły być inicjowane,
    // a następnie przekazywane do środowiska na zagnieżdżonych widokach.
    @State private var waterManager: WaterManager?
    @State private var mealPlanManager: MealPlannerManager? // Zakładam, że ten manager istnieje
    
    // --- Zmienne stanu do śledzenia widoków: ---
    @State private var showRegisterView: Bool = false
    @State private var requiresProfileSetup: Bool = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // 1. Użytkownik ZALOGOWANY
                if requiresProfileSetup {
                    // Pokaż ekran konfiguracji profilu, jeśli profil nie został jeszcze utworzony
                    // Przekazujemy statyczne menedżery za pomocą składni Environment
                    SetupProfileView(requiresProfileSetup: $requiresProfileSetup)
                        .environment(authManager)
                        .environment(profileManager)
                        .environment(storageManager)
                        .environment(waterManager!) // WaterManager musi istnieć na tym etapie
                } else if let waterManager = waterManager, let mealPlanManager = mealPlanManager {
                    // Pokaż główny widok aplikacji TYLKO gdy wszystkie menedżery są załadowane
                    // Przekazujemy WSZYSTKIE menedżery (statyczne i dynamiczne)
                    AppTabView()
                        .environment(authManager)
                        .environment(profileManager)
                        .environment(storageManager)
                        .environment(recipeManager)
                        .environment(waterManager)
                        .environment(mealPlanManager)
                } else {
                    // Wskaźnik ładowania, gdy menedżery są inicjowane i dane ładowane
                    // Używamy statycznych menedżerów, by były dostępne w środowisku
                    ProgressView("Loading user's data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .environment(authManager)
                        .environment(profileManager)
                        .environment(storageManager)
                        .environment(recipeManager)
                }
            } else {
                // 2. Użytkownik NIEZALOGOWANY
                // Pokaż LoginView lub RegisterView
                if showRegisterView {
                    RegisterView() // Przekazujemy binding do zmiany widoku
                        .environment(authManager)
                        .environment(profileManager)
                } else {
                    LoginView() // Przekazujemy binding do zmiany widoku
                        .environment(authManager)
                        .environment(profileManager)
                }
            }
        }
        // --- LOGIKA ZMIANY STANU AUTH ---
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated, let uid = authManager.user?.uid {
                // 1. ZALOGOWANO: Inicjalizacja menedżerów zależnych od userId
                // Zabezpieczenie przed ponowną inicjalizacją, jeśli user jest ten sam
                guard waterManager == nil else { return }
                
                Task {
                    do {
                        // Inicjalizacja menedżerów
                        let newWaterManager = WaterManager(userId: uid)
                        let newMealPlanManager = MealPlannerManager(userId: uid)
                        
                        // Pobranie Profilu. Ta funkcja tworzy domyślny profil, jeśli go nie ma.
                        try await profileManager.fetchUserProfile(userId: uid)
                        
                        // Po udanym pobraniu/utworzeniu profilu
                        guard let profile = profileManager.userProfile else {
                            throw NSError(domain: "AuthViewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error loading or creating profile."])
                        }
                        
                        // A. Ładowanie przepisów
                        try await recipeManager.fetchUserRecipes(userId: uid)
                        
                        // B. Obliczanie celu wody
                        newWaterManager.calculateGoal(weightKg: profile.weight, activityLevel: profile.activityLevel)
                        
                        // C. Ustawienie dynamicznych menedżerów i sprawdzenie, czy profil jest pusty
                        await MainActor.run {
                            self.waterManager = newWaterManager
                            self.mealPlanManager = newMealPlanManager
                            self.requiresProfileSetup = profile.firstName.isEmpty
                        }
                    } catch {
                        print("Error loading data after logging in: \(error)")
                        // Logika wylogowująca użytkownika przy błędzie krytycznym
                        try? authManager.signOut()
                    }
                }
                
            } else {
                // 2. WYLOGOWANO: Czyszczenie stanu
                print("Auth status changed. Logged out.")
                // Usuwanie słuchaczy i menedżerów zależnych od userId
                waterManager?.stopListening()
                mealPlanManager?.stopListening()
                waterManager = nil
                mealPlanManager = nil
                
                // Resetowanie stanu widoku
                requiresProfileSetup = false
            }
        }
        // --- OBSŁUGA STANU PRZY URUCHOMIENIU APLIKACJI ---
        .onAppear {
            authManager.setupAuthStateListener()
        }
    }
}
