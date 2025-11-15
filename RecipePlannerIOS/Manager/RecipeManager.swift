//
//  RecipeManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// RecipeManager.swift
import Foundation
import FirebaseFirestore
import Observation
import UIKit // Potrzebne do UIImage

@Observable
class RecipeManager {
    private let db = Firestore.firestore()
    
    // Stan do śledzenia wszystkich przepisów użytkownika
    var userRecipes: [Recipe] = []

    // --- POBIERANIE DANYCH ---
    
    /// Pobiera wszystkie przepisy dla danego użytkownika, sortując po dacie utworzenia.
    func fetchUserRecipes(userId: String) async throws {
        let snapshot = try await db.collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        await MainActor.run {
            self.userRecipes = snapshot.documents.compactMap { doc -> Recipe? in
                try? doc.data(as: Recipe.self)
            }
        }
    }
    
    // --- ZAPISYWANIE DANYCH ---
    
    /// Zapisuje nowy przepis, w tym przesyłanie zdjęcia do Storage.
    func saveNewRecipe(recipe: Recipe, image: UIImage?, userId: String, storageManager: StorageManager) async throws {
        
        var recipeToSave = recipe
        
        // 1. Przesyłanie zdjęcia (jeśli istnieje)
        if let image = image {
            let path = "recipes/\(userId)/\(UUID().uuidString).jpg"
            let url = try await storageManager.uploadImage(image: image, path: path)
            recipeToSave.imageURL = url // Dodaj URL do modelu
        }
        
        recipeToSave.userId = userId
        recipeToSave.createdAt = Date()
        
        // 2. Zapisywanie przepisu do Firestore
        let docRef = try db.collection("recipes").addDocument(from: recipeToSave)
        
        // 3. Aktualizacja lokalnego stanu
        recipeToSave.id = docRef.documentID
        await MainActor.run {
            self.userRecipes.insert(recipeToSave, at: 0)
        }
    }
    
    // ... (Dodasz tu metody updateRecipe i deleteRecipe) ...
}
