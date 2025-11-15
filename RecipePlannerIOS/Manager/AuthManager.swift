//
//  AuthManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// AuthManager.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable 
class AuthManager {
    // Publikowana zmienna, na którą UI będzie reagować
    var isAuthenticated: Bool = false
    var user: User?
    
    // Inicjalizacja: Sprawdzenie stanu logowania
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async { // Upewnienie się, że zmiana jest w głównym wątku
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    // --- METODY AUTH ---

    // Metoda rejestracji zwracająca UID (jedyna wersja)
    func register(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
    }

    // Metoda logowania
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // Metoda wylogowania
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // Metoda usunięcia konta
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }
}
