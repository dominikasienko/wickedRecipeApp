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

@Observable
class AuthManager {
    var isAuthenticated: Bool = false
    var user: User?
    
    private var authHandle: AuthStateDidChangeListenerHandle?

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
                print("Auth status changed. UID \(user?.uid ?? "None")")
            }
        }
    }
    
// MARK: --- METODY AUTH ---

    // Metoda rejestracji zwracająca UID
    func register(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func sendPasswordReset(withEmail email: String) async throws {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        }

    func deleteAccount() async throws {
            guard let user = user else { throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in."]) }
            try await user.delete()
        }

        func deleteUserAndData(
            profileManager: ProfileManager,
            recipeManager: RecipeManager,
            storageManager: StorageManager
        ) async throws {
            
            guard let userId = user?.uid else {
                throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user UID."])
            }

// MARK: Czyszczenie danych 
            try await profileManager.deleteUserProfile(userId: userId)
            try await recipeManager.deleteAllUserRecipes(userId: userId, storageManager: storageManager)
            try await storageManager.deleteProfileImage(userId: userId)
            try await deleteAccount()
            
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
            }
            print("Account and all associated data for \(userId) successfully deleted.")
        }
    }

