//
//  StorageManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit
import Observation

/// Zarządza operacjami przesyłania, pobierania i usuwania plików (obrazów) w Firebase Storage.
@Observable
class StorageManager {
    
    private func storage() -> Storage {
        return Storage.storage()
    }
    
    /// Definicje błędów specyficzne dla operacji Storage.
    enum StorageError: Error {
        case invalidImageFormat
        case missingAuthToken
        case missingUserId
        case ownershipMismatch
    }

    func uploadImage(image: UIImage, path: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw StorageError.invalidImageFormat
        }
        
        let imageRef = storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let _ = try await imageRef.putDataAsync(data, metadata: metadata)
        let url = try await imageRef.downloadURL()
        
        return url.absoluteString
    }
    
    // REMOVED: unused function uploadRecipeImage(image:recipeId:)
    
    func uploadProfileImage(image: UIImage, userId: String) async throws -> String {
        let path = "users/\(userId)/profile.jpg"
        return try await uploadImage(image: image, path: path)
    }
    
    func deleteImage(from urlString: String) async throws {
        // Zabezpieczenie przed niepoprawnym URL
        guard URL(string: urlString) != nil else {
            return
        }
        
        let storageRef = storage().reference(forURL: urlString)
        
        do {
            try await storageRef.delete()
        } catch let error as NSError where error.code == StorageErrorCode.objectNotFound.rawValue {
            print("StorageManager.deleteImage: File not found (expected).")
        } catch {
            throw error
        }
    }

    /// Deletes only the recipe's owner-scoped, deterministic image path.
    func deleteRecipeImage(userId: String, recipeId: String) async throws {
        guard Auth.auth().currentUser?.uid == userId else {
            throw StorageError.ownershipMismatch
        }

        let imageRef = storage().reference()
            .child("user_recipes/\(userId)/\(recipeId).jpg")
        do {
            try await imageRef.delete()
        } catch let error as NSError where error.code == StorageErrorCode.objectNotFound.rawValue {
            // A recipe without an uploaded image is already clean.
        }
    }
    
    /// Usuwa zdjęcie profilowe użytkownika na podstawie jego userId.
    func deleteProfileImage(userId: String) async throws {
        guard Auth.auth().currentUser?.uid == userId else {
            throw StorageError.ownershipMismatch
        }

        let path = "users/\(userId)/profile.jpg"
        let profileRef = storage().reference().child(path)
        
        do {
            try await profileRef.delete()
        } catch let error as NSError where error.code == StorageErrorCode.objectNotFound.rawValue {
            // Ignorujemy błąd, jeśli plik profilowy nie istnieje
        } catch {
            throw error
        }
    }
}
