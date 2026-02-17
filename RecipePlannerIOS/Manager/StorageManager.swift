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
    }

    func uploadImage(image: UIImage, path: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw StorageError.invalidImageFormat
        }
        
        let imageRef = storage().reference().child(path)
        let _ = try await imageRef.putDataAsync(data)
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
            print("StorageManager.deleteImage: Invalid URL string, skipping deletion.")
            return
        }
        
        let storageRef = storage().reference(forURL: urlString)
        
        do {
            try await storageRef.delete()
            print("StorageManager.deleteImage: Successfully deleted file at \(urlString)")
        } catch let error as NSError where error.code == StorageErrorCode.objectNotFound.rawValue {
            print("StorageManager.deleteImage: File not found (expected).")
        } catch {
            print("StorageManager.deleteImage: Error deleting file at \(urlString): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Usuwa zdjęcie profilowe użytkownika na podstawie jego userId.
    func deleteProfileImage(userId: String) async throws {
        let path = "users/\(userId)/profile.jpg"
        let profileRef = storage().reference().child(path)
        
        do {
            try await profileRef.delete()
            print("StorageManager: Profile image for \(userId) deleted successfully.")
        } catch let error as NSError where error.code == StorageErrorCode.objectNotFound.rawValue {
            // Ignorujemy błąd, jeśli plik profilowy nie istnieje
            print("StorageManager: Profile image not found (expected).")
        } catch {
            print("StorageManager: Could not delete profile image for \(userId): \(error.localizedDescription)")
            throw error
        }
    }
}
