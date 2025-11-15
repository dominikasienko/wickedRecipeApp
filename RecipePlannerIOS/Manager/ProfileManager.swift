//
//  ProfileManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// ProfileManager.swift
import Foundation
import Observation
import FirebaseFirestore

@Observable
class ProfileManager {
    private let db = Firestore.firestore()
    
    // Opublikowany stan profilu. Wystarczy prosta deklaracja 'var'.
    var userProfile: UserProfile?

    // --- ZAPIS DANYCH (Wywołane podczas rejestracji) ---
    
    /// Zapisuje dane profilowe użytkownika do Firestore.
    func saveUserProfile(profile: UserProfile, uid: String) async throws {
        // UID jest używany jako ID dokumentu
        try db.collection("users").document(uid).setData(from: profile)
        
        // Aktualizacja lokalnego stanu po zapisie
        await MainActor.run {
            self.userProfile = profile
        }
    }
    
    // --- POBIERANIE DANYCH (Wywołane po zalogowaniu) ---

    /// Pobiera profil użytkownika z Firestore.
    func fetchUserProfile(userId: String) async throws {
        let docRef = db.collection("users").document(userId)
        
        let document = try await docRef.getDocument()
        
        // Mapowanie danych na model UserProfile
        if let profile = try? document.data(as: UserProfile.self) {
            
            await MainActor.run {
                self.userProfile = profile
            }
        } else if document.exists == false {
             // Jeśli dokument nie istnieje
             print("Dokument profilu dla UID: \(userId) nie istnieje.")
             await MainActor.run {
                 self.userProfile = nil
             }
        } else {
            // Obsługa błędu parsowania
            throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Błąd mapowania danych profilu."])
        }
    }
}
