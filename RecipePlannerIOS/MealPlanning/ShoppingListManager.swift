//
//  ShoppingListManager.swift
//
//

import Foundation
import Observation

@Observable
class ShoppingListManager {
    
    private let storageKey = "ShoppingListItems"
    private let dateKey = "ShoppingListDates"
    
    struct PlanningPeriod: Codable {
        let startDate: Date?
        let endDate: Date?
    }
    
    var shoppingList: [ShoppingListItem] = []
    var currentStartDate: Date?
    var currentEndDate: Date?
    
// MARK: - Inicjalizacja
    
    init() {
        loadShoppingList()
        loadPlanningDates()
    }
    
    /// Zapisuje aktualną listę i daty do UserDefaults.
    private func saveShoppingList() {
        // Zapis listy (ShoppingListItem)
        if let encoded = try? JSONEncoder().encode(shoppingList) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } else {
            print("Failed to encode shopping list.")
        }
        
        let period = PlanningPeriod(startDate: currentStartDate, endDate: currentEndDate)
        if let encodedDates = try? JSONEncoder().encode(period) {
            UserDefaults.standard.set(encodedDates, forKey: dateKey)
        } else {
            print("Failed to encode planning dates.")
        }
    }
    
    private func loadShoppingList() {
        guard let savedData = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        if let decodedItems = try? JSONDecoder().decode([ShoppingListItem].self, from: savedData) {
            self.shoppingList = decodedItems
        } else {
            print("Failed to decode shopping list.")
        }
    }
    
    /// Ładuje daty planowania z UserDefaults.
    private func loadPlanningDates() {
        guard let savedDates = UserDefaults.standard.data(forKey: dateKey) else { return }
        
        if let decodedPeriod = try? JSONDecoder().decode(PlanningPeriod.self, from: savedDates) {
            self.currentStartDate = decodedPeriod.startDate
            self.currentEndDate = decodedPeriod.endDate
        } else {
            print("Failed to decode planning dates.")
        }
    }
    
// MARK: - Metody modyfikujące listę
    
    func setList(_ items: [ShoppingListItem], from startDate: Date? = nil, to endDate: Date? = nil) {
        self.shoppingList = items
        self.currentStartDate = startDate
        self.currentEndDate = endDate
        saveShoppingList()
    }
    
    func addItem(_ item: ShoppingListItem) {
        shoppingList.append(item)
        saveShoppingList()
    }
    
    func toggleCompletion(_ item: ShoppingListItem) {
        if let idx = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[idx].isCompleted.toggle()
            saveShoppingList()
        }
    }
    
    func deleteItem(_ item: ShoppingListItem) {
        shoppingList.removeAll { $0.id == item.id }
        saveShoppingList()
    }
    
    static func generateList(from entries: [MealPlanEntry], allRecipes: [Recipe]) -> [ShoppingListItem] {
        var aggregatedIngredients: [String: ShoppingListItem] = [:]
        
        let recipeMap: [String: Recipe] = Dictionary(uniqueKeysWithValues: allRecipes.compactMap { recipe in
            guard let id = recipe.id else { return nil }
            return (id, recipe)
        })
        
        for entry in entries {
            guard let recipe = recipeMap[entry.recipeId], recipe.servings > 0 else { continue }
            
            let multiplier = Double(entry.plannedServings) / Double(recipe.servings)
            let sourceName = recipe.name
            
            for ingredient in recipe.ingredients {
                let requiredQuantity = ingredient.quantity * multiplier
                
                let nameKey = ingredient.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let unitKey = ingredient.unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let key = "\(nameKey)_\(unitKey)"
                
                if var existingItem = aggregatedIngredients[key] {
                    existingItem.quantity += requiredQuantity
                    if !(existingItem.recipeSources?.contains(sourceName) ?? false) {
                        existingItem.recipeSources = (existingItem.recipeSources ?? []) + [sourceName]
                    }
                    aggregatedIngredients[key] = existingItem
                } else {
                    aggregatedIngredients[key] = ShoppingListItem(
                        name: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        quantity: requiredQuantity,
                        unit: ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines), 
                        isCompleted: false,
                        isManuallyAdded: false,
                        recipeSources: [sourceName]
                    )
                }
            }
        }
        return Array(aggregatedIngredients.values)
    }
}
