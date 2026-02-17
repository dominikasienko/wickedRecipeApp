//
//  ShoppingListItem.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/11/2025.
//

import Foundation

/// Reprezentuje pojedynczy, edytowalny element na liście zakupów.
struct ShoppingListItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Double
    var unit: String
    
    var isCompleted: Bool = false
    var isManuallyAdded: Bool = false
    
    var recipeSources: [String]?
    var description: String {
        let formattedQuantity = quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(quantity))" : String(format: "%.2f", quantity)
        
        if isManuallyAdded && quantity == 1 && unit.lowercased() == "piece" {
            return name
        }
        
        return "\(name): \(formattedQuantity) \(unit)"
    }
}
