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

enum RecipeDeletionError: LocalizedError, Equatable {
    case unauthenticated
    case invalidSelection
    case ownershipMismatch
    case missingOrInaccessibleRecipe
    case partialFailure(imageCleanupFailures: Int)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "You must be signed in to delete recipes."
        case .invalidSelection:
            return "The selected recipes could not be identified."
        case .ownershipMismatch:
            return "You can only delete recipes that belong to your account."
        case .missingOrInaccessibleRecipe:
            return "One or more recipes no longer exist or cannot be accessed."
        case .partialFailure:
            return "Some recipes were deleted before the remaining operation failed."
        }
    }
}

struct RecipeDeletionResult {
    let deletedCount: Int
    let imageCleanupFailures: Int
}

@Observable
class RecipeManager {

    private enum RecipeSaveError: LocalizedError {
        case unauthenticated
        case ownershipMismatch

        var errorDescription: String? {
            switch self {
            case .unauthenticated:
                return "You must be signed in to save a recipe."
            case .ownershipMismatch:
                return "You can only save recipes that belong to your account."
            }
        }
    }
    
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
        guard let authenticatedUserID = Auth.auth().currentUser?.uid else {
            throw RecipeSaveError.unauthenticated
        }
        guard authenticatedUserID == recipe.userId else {
            throw RecipeSaveError.ownershipMismatch
        }

        var recipeToSave = recipe
        let collection = db().collection("recipes")
        let isNewRecipe = recipeToSave.id == nil
        let documentReference: DocumentReference

        if let recipeID = recipeToSave.id {
            documentReference = collection.document(recipeID)
        } else {
            documentReference = collection.document()
            recipeToSave.id = documentReference.documentID
            recipeToSave.dateAdded = Date()
        }

        var uploadedImageURL: String?
        if let newImage {
            let imagePath = "user_recipes/\(recipeToSave.userId)/\(documentReference.documentID).jpg"
            let newURL = try await storageManager.uploadImage(image: newImage, path: imagePath)
            uploadedImageURL = newURL
            recipeToSave.imageURL = newURL
        }

        do {
            if isNewRecipe {
                try await documentReference.setData(try createData(for: recipeToSave))
                print("RecipeManager: Recipe created.")
            } else {
                // Do not re-write ownership fields. Firestore rules can safely require
                // that userId and dateAdded stay unchanged for edits.
                try await documentReference.updateData(try updateData(for: recipeToSave))
                print("RecipeManager: Recipe updated.")
            }
        } catch {
            // Keep the current recipe image intact when the Firestore write is rejected.
            if let uploadedImageURL {
                try? await storageManager.deleteImage(from: uploadedImageURL)
            }
            throw error
        }

        // The document now points at the new image (or no image), so old storage data
        // can be removed without risking a broken recipe if the database write failed.
        if let existingImageURL, existingImageURL != recipeToSave.imageURL {
            try? await storageManager.deleteImage(from: existingImageURL)
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

    private func createData(for recipe: Recipe) throws -> [String: Any] {
        try Firestore.Encoder().encode(recipe)
    }

    private func updateData(for recipe: Recipe) throws -> [String: Any] {
        var data = try Firestore.Encoder().encode(recipe)

        // Existing security rules often protect these fields with an equality check.
        data.removeValue(forKey: "userId")
        data.removeValue(forKey: "dateAdded")

        // Explicit deletes allow users to clear optional content during an edit.
        if recipe.sections == nil {
            data["sections"] = FieldValue.delete()
        }
        if recipe.notes == nil {
            data["notes"] = FieldValue.delete()
        }
        if recipe.imageURL == nil {
            data["imageURL"] = FieldValue.delete()
        }
        if recipe.nutrition == nil {
            data["nutrition"] = FieldValue.delete()
        }

        return data
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

    func updateRecipeNutrition(recipeId: String, nutrition: RecipeNutrition?) async throws {
        let docRef = db().collection("recipes").document(recipeId)

        await MainActor.run {
            if let index = self.userRecipes.firstIndex(where: { $0.id == recipeId }) {
                self.userRecipes[index].nutrition = nutrition
            }
        }

        if let nutrition {
            let nutritionData = try Firestore.Encoder().encode(nutrition)
            do {
                try await docRef.updateData(["nutrition": nutritionData])
            } catch {
                // Some documents can briefly fail updateData during creation races.
                try await docRef.setData(["nutrition": nutritionData], merge: true)
            }
        } else {
            try await docRef.updateData(["nutrition": FieldValue.delete()])
        }
    }

// MARK: --- USUWANIE DANYCH ---
    
    /// Shared single- and multi-recipe deletion path. Firestore ownership is
    /// verified before any writes; security rules remain the final authority.
    @discardableResult
    func deleteRecipe(recipe: Recipe, storageManager: StorageManager) async throws -> RecipeDeletionResult {
        try await deleteRecipes(recipes: [recipe], storageManager: storageManager)
    }

    @discardableResult
    func deleteRecipes(recipes: [Recipe], storageManager: StorageManager) async throws -> RecipeDeletionResult {
        guard let authenticatedUserID = Auth.auth().currentUser?.uid else {
            throw RecipeDeletionError.unauthenticated
        }

        let recipeIDs = try Self.validatedRecipeIDs(
            recipes: recipes,
            authenticatedUserID: authenticatedUserID
        )
        try await verifyRecipeOwnership(recipeIDs, userID: authenticatedUserID)

        var deletedIDs: [String] = []
        for batchIDs in Self.chunks(recipeIDs, maximumSize: 450) {
            let batch = db().batch()
            batchIDs.forEach { id in
                batch.deleteDocument(db().collection("recipes").document(id))
            }

            do {
                try await batch.commit()
                deletedIDs.append(contentsOf: batchIDs)
            } catch {
                if !deletedIDs.isEmpty {
                    let cleanupFailures = await removeRecipeImages(
                        recipeIDs: deletedIDs,
                        userID: authenticatedUserID,
                        storageManager: storageManager
                    )
                    await removeFromMemory(recipeIDs: deletedIDs)
                    if cleanupFailures > 0 {
                        print("RecipeManager: \(cleanupFailures) image(s) could not be removed after a partial deletion.")
                    }
                    throw RecipeDeletionError.partialFailure(imageCleanupFailures: cleanupFailures)
                }
                throw error
            }
        }

        let imageCleanupFailures = await removeRecipeImages(
            recipeIDs: deletedIDs,
            userID: authenticatedUserID,
            storageManager: storageManager
        )
        await removeFromMemory(recipeIDs: deletedIDs)

        return RecipeDeletionResult(
            deletedCount: deletedIDs.count,
            imageCleanupFailures: imageCleanupFailures
        )
    }

    static func validatedRecipeIDs(
        recipes: [Recipe],
        authenticatedUserID: String
    ) throws -> [String] {
        guard !authenticatedUserID.isEmpty else {
            throw RecipeDeletionError.unauthenticated
        }
        guard !recipes.isEmpty else {
            throw RecipeDeletionError.invalidSelection
        }

        var seenIDs = Set<String>()
        var validatedIDs: [String] = []

        for recipe in recipes {
            guard recipe.userId == authenticatedUserID else {
                throw RecipeDeletionError.ownershipMismatch
            }
            guard let id = recipe.id, !id.isEmpty, !id.contains("/") else {
                throw RecipeDeletionError.invalidSelection
            }
            if seenIDs.insert(id).inserted {
                validatedIDs.append(id)
            }
        }

        return validatedIDs
    }

    private func verifyRecipeOwnership(_ recipeIDs: [String], userID: String) async throws {
        let recipes = db().collection("recipes")

        // Firestore's `in` query limit is 30 IDs; querying by owner also ensures
        // the read complies with owner-only Firestore security rules.
        for idChunk in Self.chunks(recipeIDs, maximumSize: 30) {
            let snapshot = try await recipes
                .whereField("userId", isEqualTo: userID)
                .whereField(FieldPath.documentID(), in: idChunk)
                .getDocuments()
            let returnedIDs = Set(snapshot.documents.compactMap { document -> String? in
                guard document.data()["userId"] as? String == userID else { return nil }
                return document.documentID
            })
            guard returnedIDs == Set(idChunk) else {
                let unavailableIDs = Set(idChunk).subtracting(returnedIDs)
                await removeFromMemory(recipeIDs: Array(unavailableIDs))
                throw RecipeDeletionError.missingOrInaccessibleRecipe
            }
        }
    }

    private func removeFromMemory(recipeIDs: [String]) async {
        guard !recipeIDs.isEmpty else { return }
        let ids = Set(recipeIDs)
        await MainActor.run {
            self.userRecipes.removeAll { recipe in
                guard let id = recipe.id else { return false }
                return ids.contains(id)
            }
        }
    }

    private func removeRecipeImages(
        recipeIDs: [String],
        userID: String,
        storageManager: StorageManager
    ) async -> Int {
        var failures = 0
        for recipeID in recipeIDs {
            do {
                try await storageManager.deleteRecipeImage(userId: userID, recipeId: recipeID)
            } catch {
                failures += 1
                print("RecipeManager: Could not remove image for recipe \(recipeID): \(error.localizedDescription)")
            }
        }
        return failures
    }

    private static func chunks<Element>(_ elements: [Element], maximumSize: Int) -> [[Element]] {
        guard maximumSize > 0, !elements.isEmpty else { return [] }
        return stride(from: 0, to: elements.count, by: maximumSize).map { start in
            Array(elements[start..<min(start + maximumSize, elements.count)])
        }
    }
    
    /// Removes owner-scoped recipe images first, then deletes their Firestore documents.
    func deleteAllUserRecipes(userId: String, storageManager: StorageManager) async throws {
        guard Auth.auth().currentUser?.uid == userId else {
            throw RecipeDeletionError.ownershipMismatch
        }

        let snapshot = try await db().collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        guard snapshot.documents.allSatisfy({ $0.data()["userId"] as? String == userId }) else {
            throw RecipeDeletionError.ownershipMismatch
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for document in snapshot.documents {
                let recipeID = document.documentID
                group.addTask {
                    try await storageManager.deleteRecipeImage(userId: userId, recipeId: recipeID)
                }
            }
            try await group.waitForAll()
        }

        for start in stride(from: 0, to: snapshot.documents.count, by: 450) {
            let batch = db().batch()
            for document in snapshot.documents[start..<min(start + 450, snapshot.documents.count)] {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }

        await MainActor.run {
            self.userRecipes = []
        }
        print("RecipeManager: All account recipes removed.")
    }

    func clearLocalData() {
        userRecipes = []
    }
}
