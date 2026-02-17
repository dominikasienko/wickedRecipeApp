//
//  RecipeManager.swift 
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import Foundation
import FirebaseFirestore
import Observation
import UIKit
import FirebaseAuth

@Observable
class RecipeManager {
    
    /// Funkcja pomocnicza do bezpiecznego pobierania instancji Firestore.
    private func db() -> Firestore {
        return Firestore.firestore()
    }
    
    var userRecipes: [Recipe] = []
    
    func saveRecipe(
            recipe: Recipe,
            newImage: UIImage?,
            existingImageURL: String?,
            storageManager: StorageManager
        ) async throws -> Recipe {
            
            var recipeToSave = recipe
            
            if recipeToSave.id == nil {
                recipeToSave.dateAdded = Date()
            }
            if let newImage = newImage {
                let docId = recipeToSave.id ?? UUID().uuidString
                
                let imagePath = "user_recipes/\(recipeToSave.userId)/\(docId).jpg"
                
                let newURL = try await storageManager.uploadImage(image: newImage, path: imagePath)
                recipeToSave.imageURL = newURL
                
                if let oldURL = existingImageURL, oldURL != newURL {
                    try? await storageManager.deleteImage(from: oldURL)
                }
                
            } else if existingImageURL != nil && recipeToSave.imageURL == nil {
                try? await storageManager.deleteImage(from: existingImageURL!)
            }
            let collection = db().collection("recipes")
            
            if let id = recipeToSave.id {
                try collection.document(id).setData(from: recipeToSave, merge: true)
                print("RecipeManager: Updated recipe \(id)")
            } else {
                let documentRef = try collection.addDocument(from: recipeToSave)
                recipeToSave.id = documentRef.documentID
                print("RecipeManager: Added new recipe \(recipeToSave.id!)")
            }
            
            await MainActor.run {
                if let index = self.userRecipes.firstIndex(where: { $0.id == recipeToSave.id }) {
                    self.userRecipes[index] = recipeToSave
                } else {
                    self.userRecipes.insert(recipeToSave, at: 0)
                }
            }
            
            return recipeToSave
        }
    
// MARK: --- POBIERANIE DANYCH ---
    
    /// Pobiera wszystkie przepisy dla danego użytkownika, sortując po dacie utworzenia.
    func fetchUserRecipes(userId: String) async throws {
        let snapshot = try await db().collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "dateAdded", descending: true)
            .getDocuments()
        
        await MainActor.run {
            self.userRecipes = snapshot.documents.compactMap { doc -> Recipe? in
                var recipe = try? doc.data(as: Recipe.self)
                recipe?.id = doc.documentID
                return recipe
            }
        }
    }
    
// MARK: --- ZARZĄDZANIE ULUBIONYMI ---\
    
    /// Przełącza status 'isFavorite' dla danego przepisu, zarówno lokalnie, jak i w Firestore.
    func toggleFavorite(recipeId: String) async throws {
        // Lokalna zmiana stanu, aby UI zareagował natychmiast
        await MainActor.run {
            if let index = self.userRecipes.firstIndex(where: { $0.id == recipeId }) {
                self.userRecipes[index].isFavorite.toggle()
            }
        }
        
        guard let docRef = userRecipes.first(where: { $0.id == recipeId })?.id else {
            throw NSError(domain: "RecipeError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Recipe ID not found."])
        }
        let newFavoriteState = userRecipes.first(where: { $0.id == recipeId })?.isFavorite ?? false
        
        try await db().collection("recipes").document(docRef)
            .updateData(["isFavorite": newFavoriteState])
        
        print("RecipeManager: Toggled favorite status for recipe \(recipeId) to \(newFavoriteState)")
    }

// MARK: --- USUWANIE DANYCH ---
    
    /// Usuwa pojedynczy przepis z Firestore i powiązany obraz ze Storage.
    func deleteRecipe(recipe: Recipe, storageManager: StorageManager) async throws {
        guard let recipeId = recipe.id else {
            throw NSError(domain: "RecipeError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Recipe ID not found."])
        }
        
        try await db().collection("recipes").document(recipeId).delete()
        print("RecipeManager: Deleted document \(recipeId)")

        if let url = recipe.imageURL {
            try? await storageManager.deleteImage(from: url)
        }

        await MainActor.run {
            self.userRecipes.removeAll(where: { $0.id == recipeId })
        }
    }
    
    /// Masowo usuwa wszystkie przepisy użytkownika i powiązane z nimi zdjęcia.
    func deleteAllUserRecipes(userId: String, storageManager: StorageManager) async throws {
        print("RecipeManager: Starting mass deletion of recipes for user: \(userId)")

        let snapshot = try await db().collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let recipesToDelete: [(id: String, imageURL: String?)] = snapshot.documents.compactMap { doc in
            let recipe = try? doc.data(as: Recipe.self)
            return (id: doc.documentID, imageURL: recipe?.imageURL)
        }

        await withThrowingTaskGroup(of: Void.self) { group in
            for recipe in recipesToDelete {
                group.addTask {
                    // Usuń dokument
                    try await self.db().collection("recipes").document(recipe.id).delete()
                    if let url = recipe.imageURL {
                        try? await storageManager.deleteImage(from: url)
                    }
                }
            }
        }
        
        await MainActor.run {
            self.userRecipes = []
        }
        print("RecipeManager: Successfully deleted \(recipesToDelete.count) recipes for user: \(userId)")
    }
}
