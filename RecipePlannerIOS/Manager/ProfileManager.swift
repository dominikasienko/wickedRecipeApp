//
//  ProfileManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@Observable
class ProfileManager {
    private func db() -> Firestore {
        return Firestore.firestore()
    }
    
    /// Prywatna funkcja, która bezpiecznie zwraca instancję Firestore.
        private func getFirestoreInstance() -> Firestore {
            return Firestore.firestore()
        }
    
    var userProfile: UserProfile?

// MARK:  --- UTWORZENIE DOMYŚLNEGO PROFILU ---
    private func createDefaultProfile(userId: String) -> UserProfile {
        return UserProfile(
            id: nil,
            userId: userId,
            firstName: "",
            lastName: "",
            dateOfBirth: Date(),
            weight: 70.0,
            height: 170.0,
            gender: "Undefined",
            activityLevel: "Moderate activity",
            selectedDiets: [],
            profileImageURL: nil
        )
    }
    
    /// Zapisuje dane profilowe użytkownika do Firestore.
    func saveUserProfile(profile: UserProfile, uid: String) async throws {
        print("ProfileManager.saveUserProfile: Saving profile for uid=\(uid)")
        
        let collectionRef = db().collection("users")
        
        do {
            try collectionRef.document(uid).setData(from: profile)
            await MainActor.run {
                self.userProfile = profile
            }
            print("ProfileManager.saveUserProfile: Profile saved successfully.")
        } catch {
            print("ProfileManager.saveUserProfile: Failed to save profile for uid=\(uid): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Pobiera profil użytkownika z Firestore. Jeśli profil nie istnieje, tworzy domyślny.
    func fetchUserProfile(userId: String) async throws {
        print("ProfileManager.fetchUserProfile: Fetching profile for uid=\(userId)")
        
        let docRef = db().collection("users").document(userId)
        let document = try await docRef.getDocument()

        if document.exists {
            do {
                let profile = try document.data(as: UserProfile.self)
                await MainActor.run {
                    self.userProfile = profile
                }
                print("ProfileManager.fetchUserProfile: Loaded profile for uid=\(userId)")
            } catch {
                print("ProfileManager.fetchUserProfile: Mapping error for uid=\(userId): \(error)")
                throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile data mapping error. Verify that the UserProfile model matches the Firestore data."])
            }
        } else {
            print("ProfileManager.fetchUserProfile: No document for uid=\(userId). Creating default profile.")
            
            let defaultProfile = createDefaultProfile(userId: userId)
            do {
                try docRef.setData(from: defaultProfile)
            } catch {
                print("ProfileManager.fetchUserProfile: Failed to save default profile for uid=\(userId): \(error.localizedDescription)")
                throw error
            }

            await MainActor.run {
                self.userProfile = defaultProfile
            }
            print("ProfileManager.fetchUserProfile: Default profile created for uid=\(userId)")
        }
    }
    
    /// Usuwa dokument profilu użytkownika z kolekcji 'users'.
        func deleteUserProfile(userId: String) async throws {
            let db = getFirestoreInstance()
            let docRef = db.collection("users").document(userId)
            
            do {
                try await docRef.delete()
                print("ProfileManager: User profile \(userId) deleted successfully from Firestore.")
                await MainActor.run {
                    self.userProfile = nil
                }
            } catch {
                print("ProfileManager: Error deleting user profile \(userId): \(error.localizedDescription)")
                throw error
            }
        }
}
