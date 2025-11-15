//
//  IngredientsSection.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// IngredientsSection.swift (Poprawiona)
import SwiftUI

struct IngredientsSection: View {
    @Binding var ingredients: [Ingredient]
    let units = ["g", "ml", "cups", "Tbsp", "tsp", "pinch", "piece", "package"]

    var body: some View {
        Section("Ingredients") {
            // Używamy .id, aby zapewnić stabilny identyfikator dla każdego wiersza
            ForEach($ingredients) { $ingredient in // Używamy $ingredients (Binding)
                HStack {
                    // Nazwa Składnika
                    TextField("Name", text: $ingredient.name)
                        .frame(minWidth: 100)
                    
                    Spacer()
                    
                    // Ilość
                    TextField("Quantity", value: $ingredient.quantity, formatter: NumberFormatter.decimalFormatter) // Używamy Formattera
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    
                    // Jednostka
                    Picker("Unit", selection: $ingredient.unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            .onDelete(perform: deleteIngredient)

            Button("Add ingredient") {
                ingredients.append(Ingredient(name: "", quantity: 0, unit: "g"))
            }
        }
    }

    private func deleteIngredient(offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
}

