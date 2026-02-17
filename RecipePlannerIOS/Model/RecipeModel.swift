//
//  RecipeModel.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 1/12/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Recipe Section

struct RecipeSection: Codable, Identifiable, Hashable, Equatable {
    var id = UUID()
    var title: String
    var ingredients: [Ingredient]
    var instructions: [String]
    
    init(title: String, ingredients: [Ingredient], instructions: [String]) {
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

// MARK: - Recipe

struct Recipe: Codable, Identifiable, Hashable, Equatable {
    var id: String?
    let userId: String
    
    // --- PODSTAWOWE DANE ---
    var name: String
    var category: String
    
    // --- CZASY I ILOŚCI ---
    var preparationTimeMinutes: Int
    var servings: Int
    
    // --- SKŁADNIKI I INSTRUKCJE
    var ingredients: [Ingredient]
    var instructions: [String]
    var sections: [RecipeSection]?
    
    var notes: String?
    var imageURL: String?
    var dateAdded: Date
    var isFavorite: Bool = false
    
    init(id: String? = nil, userId: String, name: String, category: String, preparationTimeMinutes: Int, servings: Int, ingredients: [Ingredient], instructions: [String], sections: [RecipeSection]? = nil, notes: String? = nil, imageURL: String? = nil, dateAdded: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.category = category
        self.preparationTimeMinutes = preparationTimeMinutes
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.sections = sections
        self.notes = notes
        self.imageURL = imageURL
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
    }
    
    // MARK: - Equatable / Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Ingredient

struct Ingredient: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var quantity: Double
    var unit: String

    init(id: UUID = UUID(), name: String, quantity: Double, unit: String) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
    
    var descriptionForAPI: String {
        let formattedQuantity = quantity.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", quantity) :
            String(format: "%.1f", quantity)
            
        return "\(formattedQuantity) \(unit) \(name)"
    }
        
    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case unit
    }
}
