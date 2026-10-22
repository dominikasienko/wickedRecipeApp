//
//  RecipeModel.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 1/12/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Stored Nutrition

struct RecipeNutrition: Codable, Hashable, Equatable, Sendable {
    var caloriesPerServing: Double
    var carbohydratesPerServing: Double
    var fatPerServing: Double
    var proteinPerServing: Double
    var servings: Int
    var matchedIngredients: Int
    var totalIngredients: Int
    var missingIngredients: [String]
    var calculatedAt: Date
}

// MARK: - Recipe Section

struct RecipeSection: Codable, Identifiable, Hashable, Equatable, Sendable {
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

struct Recipe: Codable, Identifiable, Hashable, Equatable, Sendable {
    var id: String? = nil
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
    var nutrition: RecipeNutrition?
    var dateAdded: Date
    var isFavorite: Bool = false
    
    init(id: String? = nil, userId: String, name: String, category: String, preparationTimeMinutes: Int, servings: Int, ingredients: [Ingredient], instructions: [String], sections: [RecipeSection]? = nil, notes: String? = nil, imageURL: String? = nil, nutrition: RecipeNutrition? = nil, dateAdded: Date = Date(), isFavorite: Bool = false) {
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
        self.nutrition = nutrition
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

    enum CodingKeys: String, CodingKey {
        case userId
        case name
        case category
        case preparationTimeMinutes
        case servings
        case ingredients
        case instructions
        case sections
        case notes
        case imageURL
        case nutrition
        case dateAdded
        case isFavorite
    }
}

// MARK: - Ingredient

struct Ingredient: Codable, Hashable, Identifiable, Sendable {
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
        "\(IngredientQuantityFormatter.formatted(quantity, locale: Locale(identifier: "en_US_POSIX"))) \(unit) \(name)"
    }
        
    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case unit
    }
}

enum IngredientQuantityFormatter {
    static func sanitizedInput(_ rawValue: String, locale: Locale) -> String {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let normalized = rawValue
            .replacingOccurrences(of: ",", with: decimalSeparator)
            .replacingOccurrences(of: ".", with: decimalSeparator)

        var result = ""
        var hasSeparator = false
        var fractionDigits = 0

        for character in normalized {
            if character.isWholeNumber {
                if hasSeparator {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                result.append(character)
                continue
            }

            if String(character) == decimalSeparator, !hasSeparator {
                hasSeparator = true
                if result.isEmpty {
                    result = "0"
                }
                result.append(character)
            }
        }

        return result
    }

    static func parsedInput(_ value: String, locale: Locale) -> Double? {
        formatter(locale: locale).number(from: value)?.doubleValue
    }

    static func formatted(_ value: Double, locale: Locale) -> String {
        formatter(locale: locale).string(from: NSNumber(value: value)) ?? "0"
    }

    private static func formatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.isLenient = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        return formatter
    }
}
