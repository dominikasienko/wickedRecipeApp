//
//  AuthManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

enum AccountDeletionError: Error {
    case missingUser
    case unsupportedSignInProvider
    case reauthenticationFailed
    case dataCleanupFailed
    case authenticationDeletionFailed
}

@Observable
class AuthManager {
    var isAuthenticated: Bool = false
    var isCompletingRegistration = false
    var user: User?

    var usesPasswordProvider: Bool {
        user?.providerData.contains { $0.providerID == "password" } == true
    }
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var googleOAuthProvider: OAuthProvider?

    init() {
        print("AuthManager: Instance initialized. Awaiting Firebase configuration...")
    }

    func setupAuthStateListener() {
        if authHandle != nil { return }
        
        // Bezpieczne wywołanie Auth.auth() po konfiguracji FirebaseApp
        self.authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
                print("Auth status changed.")
            }
        }
    }
    
// MARK: --- METODY AUTH ---

    // Metoda rejestracji zwracająca UID
    func register(email: String, password: String) async throws -> String {
        isCompletingRegistration = true
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return result.user.uid
        } catch {
            isCompletingRegistration = false
            throw error
        }
    }

    func finishRegistration() {
        isCompletingRegistration = false
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signInWithGoogle() async throws {
        let provider = OAuthProvider(providerID: AuthProviderID.google.rawValue)
        provider.scopes = ["email", "profile"]
        
        googleOAuthProvider = provider
        defer { googleOAuthProvider = nil }
        
        _ = try await Auth.auth().signIn(with: provider, uiDelegate: nil)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func sendPasswordReset(withEmail email: String) async throws {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        }

    func deleteUserAndData(
        password: String?,
        profileManager: ProfileManager,
        recipeManager: RecipeManager,
        storageManager: StorageManager,
        waterManager: WaterManager,
        mealPlannerManager: MealPlannerManager,
        shoppingListManager: ShoppingListManager,
        notificationManager: NotificationManager
    ) async throws {
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == user?.uid else {
            throw AccountDeletionError.missingUser
        }

        do {
            try await reauthenticate(password: password)
        } catch {
            throw AccountDeletionError.reauthenticationFailed
        }

        let userId = currentUser.uid
        do {
            try await recipeManager.deleteAllUserRecipes(userId: userId, storageManager: storageManager)
            try await waterManager.deleteAllWaterRecords()
            try await mealPlannerManager.deleteAllMealPlanEntries()
            try await storageManager.deleteProfileImage(userId: userId)
            try await profileManager.deleteUserProfile(userId: userId)
        } catch {
            throw AccountDeletionError.dataCleanupFailed
        }

        do {
            try await currentUser.delete()
        } catch {
            await clearLocalAccountData(
                profileManager: profileManager,
                recipeManager: recipeManager,
                waterManager: waterManager,
                mealPlannerManager: mealPlannerManager,
                shoppingListManager: shoppingListManager,
                notificationManager: notificationManager
            )
            throw AccountDeletionError.authenticationDeletionFailed
        }

        await clearLocalAccountData(
            profileManager: profileManager,
            recipeManager: recipeManager,
            waterManager: waterManager,
            mealPlannerManager: mealPlannerManager,
            shoppingListManager: shoppingListManager,
            notificationManager: notificationManager
        )

        await MainActor.run {
            self.user = nil
            self.isAuthenticated = false
        }
    }

    private func clearLocalAccountData(
        profileManager: ProfileManager,
        recipeManager: RecipeManager,
        waterManager: WaterManager,
        mealPlannerManager: MealPlannerManager,
        shoppingListManager: ShoppingListManager,
        notificationManager: NotificationManager
    ) async {
        await MainActor.run {
            waterManager.clearLocalData()
            mealPlannerManager.clearLocalData()
            recipeManager.clearLocalData()
            profileManager.clearLocalData()
            shoppingListManager.clearAll()
            AppPreferenceStore.resetAfterAccountDeletion()
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
            notificationManager.cancelAllWaterReminders()
        }
    }

    func reauthenticate(password: String?) async throws {
        guard let user = Auth.auth().currentUser,
              user.uid == self.user?.uid else {
            throw AccountDeletionError.missingUser
        }
        let providers = Set(user.providerData.map(\.providerID))

        if providers.contains("password") {
            guard let email = user.email, let password, !password.isEmpty else {
                throw AccountDeletionError.reauthenticationFailed
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            return
        }

        if providers.contains(AuthProviderID.google.rawValue) {
            let provider = OAuthProvider(providerID: AuthProviderID.google.rawValue)
            provider.scopes = ["email", "profile"]
            try await user.reauthenticate(with: provider, uiDelegate: nil)
            return
        }

        throw AccountDeletionError.unsupportedSignInProvider
    }
}
