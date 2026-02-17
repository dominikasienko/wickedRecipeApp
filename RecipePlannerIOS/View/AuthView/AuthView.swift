//
//  AuthView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import FirebaseAuth
import Observation

struct AuthView: View {
    
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(RecipeManager.self) private var recipeManager
    
    
    @State private var waterManager: WaterManager?
    @State private var mealPlanManager: MealPlannerManager?
    @State private var shoppingListManager = ShoppingListManager()
    
    @State private var showRegisterView: Bool = false
    private let loadingImageName = "launchScreen"
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
               if let waterManager = waterManager, let mealPlanManager = mealPlanManager {
                    AppTabView()
                        .environment(authManager)
                        .environment(profileManager)
                        .environment(storageManager)
                        .environment(recipeManager)
                        .environment(waterManager)
                        .environment(mealPlanManager)
                        .environment(shoppingListManager)
                } else {
                    CustomLoadingView(imageName: loadingImageName)
                        .environment(authManager)
                        .environment(profileManager)
                        .environment(storageManager)
                        .environment(recipeManager)
                        .environment(shoppingListManager)
                }
            } else {
                if showRegisterView {
                    RegisterView()
                        .environment(authManager)
                        .environment(profileManager)
                } else {
                    LoginView()
                        .environment(authManager)
                        .environment(profileManager)
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated, let uid = authManager.user?.uid {
                guard waterManager == nil else { return }
                
                Task {
                    do {
                        let newWaterManager = WaterManager(userId: uid)
                        let newMealPlanManager = MealPlannerManager(userId: uid)
                        try await profileManager.fetchUserProfile(userId: uid)
                        
                        guard let profile = profileManager.userProfile else {
                            throw NSError(domain: "AuthViewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error loading or creating profile."])
                        }
                        
                        try await recipeManager.fetchUserRecipes(userId: uid)
                        newWaterManager.calculateGoal(weightKg: profile.weight, activityLevel: profile.activityLevel)
                        
                        await MainActor.run {
                            self.waterManager = newWaterManager
                            self.mealPlanManager = newMealPlanManager
                        }
                    } catch {
                        print("Error loading data after logging in: \(error)")
                        try? authManager.signOut()
                    }
                }
            } else {
                print("Auth status changed. Logged out.")
                waterManager?.stopListening()
                mealPlanManager?.stopListening()
                waterManager = nil
                mealPlanManager = nil
                shoppingListManager.shoppingList = []
            }
        }
        .onAppear {
            authManager.setupAuthStateListener()
        }
    }
}
