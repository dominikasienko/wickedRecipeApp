//
//  ProfileManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

@preconcurrency import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

private enum ProfileWriteError: Error {
    case timedOut
}

private final class ProfileWriteContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func complete(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

private func profileWriteTimeout(for result: ProfileWriteContinuation) -> Task<Void, Never> {
    Task {
        do {
            try await Task.sleep(for: .seconds(30))
        } catch is CancellationError {
            return
        } catch {
            result.complete(.failure(error))
            return
        }

        result.complete(.failure(ProfileWriteError.timedOut))
    }
}

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
    private(set) var didCreateDefaultProfile = false

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
            gender: "other",
            activityLevel: "",
            selectedDiets: [],
            weightGoal: nil,
            profileImageURL: nil,
            canUseGeneralEstimates: false
        )
    }
    
    /// Zapisuje dane profilowe użytkownika do Firestore.
    func saveUserProfile(profile: UserProfile, uid: String, removingProfileImage: Bool = false) async throws {
        let collectionRef = db().collection("users")
        let normalizedProfile = profile.canonicalizedForStorage()
        let document = collectionRef.document(uid)
        
        do {
            if removingProfileImage {
                guard Auth.auth().currentUser?.uid == uid,
                      normalizedProfile.profileImageURL == nil else {
                    throw NSError(domain: "ProfileError", code: 403)
                }
                try await writeProfileRemovingImage(normalizedProfile, to: document)
            } else {
                try await writeProfile(normalizedProfile, to: document)
            }
            await MainActor.run {
                self.userProfile = normalizedProfile
                self.didCreateDefaultProfile = false
            }
            do {
                try await HydrationTargetHistoryStore.recordCurrentDay(
                    profile: normalizedProfile,
                    userID: uid
                )
            } catch {
                print("ProfileManager: Hydration target history could not be updated: \(error.localizedDescription)")
            }
        } catch {
            print("ProfileManager: Profile save failed.")
            throw error
        }
    }
    
    /// Pobiera profil użytkownika z Firestore. Jeśli profil nie istnieje, tworzy domyślny.
    func fetchUserProfile(userId: String) async throws {
        await MainActor.run { self.didCreateDefaultProfile = false }
        let docRef = db().collection("users").document(userId)
        let document = try await docRef.getDocument()

        if document.exists {
            do {
                let profile = try document.data(as: UserProfile.self)
                await MainActor.run {
                    self.userProfile = profile
                }
                do {
                    try await HydrationTargetHistoryStore.recordCurrentDay(profile: profile, userID: userId)
                } catch {
                    print("ProfileManager: Today's hydration target could not be recorded: \(error.localizedDescription)")
                }
            } catch {
                print("ProfileManager: Profile data could not be read.")
                throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile data mapping error. Verify that the UserProfile model matches the Firestore data."])
            }
        } else {
            let defaultProfile = createDefaultProfile(userId: userId)
            do {
                try await writeProfile(defaultProfile, to: docRef)
            } catch {
                print("ProfileManager: Default profile creation failed.")
                throw error
            }

            await MainActor.run {
                self.userProfile = defaultProfile
                self.didCreateDefaultProfile = true
            }
            do {
                try await HydrationTargetHistoryStore.recordCurrentDay(profile: defaultProfile, userID: userId)
            } catch {
                print("ProfileManager: Today's unavailable hydration target could not be recorded: \(error.localizedDescription)")
            }
        }
    }
    
        /// Usuwa dokument profilu użytkownika z kolekcji 'users'.
        func deleteUserProfile(userId: String) async throws {
            guard Auth.auth().currentUser?.uid == userId else {
                throw NSError(domain: "ProfileError", code: 403)
            }

            let db = getFirestoreInstance()
            let docRef = db.collection("users").document(userId)
            
            do {
                try await docRef.delete()
            } catch {
                print("ProfileManager: Profile removal failed.")
                throw error
            }
        }

    func clearLocalData() {
        userProfile = nil
        didCreateDefaultProfile = false
    }

    private func writeProfile(_ profile: UserProfile, to document: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let result = ProfileWriteContinuation(continuation)
            let timeout = profileWriteTimeout(for: result)

            do {
                try document.setData(from: profile) { error in
                    timeout.cancel()
                    if let error {
                        result.complete(.failure(error))
                    } else {
                        result.complete(.success(()))
                    }
                }
            } catch {
                timeout.cancel()
                result.complete(.failure(error))
            }
        }
    }

    private func writeProfileRemovingImage(_ profile: UserProfile, to document: DocumentReference) async throws {
        var fields = try Firestore.Encoder().encode(profile)
        fields["profileImageURL"] = FieldValue.delete()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let result = ProfileWriteContinuation(continuation)
            let timeout = profileWriteTimeout(for: result)

            document.updateData(fields) { error in
                timeout.cancel()
                if let error {
                    result.complete(.failure(error))
                } else {
                    result.complete(.success(()))
                }
            }
        }
    }
}
