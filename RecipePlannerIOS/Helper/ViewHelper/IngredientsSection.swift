//
//  IngredientsSection.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/12/2025.
//

import SwiftUI

private struct IngredientRowEditor: View {
    @Binding var ingredient: Ingredient
    let units: [String]
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Quantity
            TextField("Qty", value: $ingredient.quantity, formatter: NumberFormatter.decimalFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.1))
                .cornerRadius(5)
            
            // Unit Picker
            Picker("Unit", selection: $ingredient.unit) {
                ForEach(units, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.wickedGreen)
            .frame(width: 85)
            
            // Name
            TextField("Ingredient", text: $ingredient.name)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .listRowBackground(Color.black.opacity(0.2))
        .padding(.vertical, 2)
    }
}

private struct SectionalIngredientsContent: View {
    @Binding var sections: [RecipeSection]
    let units: [String]

    var body: some View {
        ForEach(sections) { section in
            let sectionBinding = binding(for: section.id)
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(section.ingredients) { ingredient in
                    if let ingredientBinding = binding(for: ingredient.id, in: section.id) {
                        IngredientRowEditor(
                            ingredient: ingredientBinding,
                            units: units,
                            onDelete: {
                                deleteIngredient(ingredientID: ingredient.id, in: section.id)
                            }
                        )
                    }
                }
                .onMove { indices, newOffset in
                    moveIngredients(in: section.id, from: indices, to: newOffset)
                }
                
                Button(action: {
                    withAnimation {
                        var new = Ingredient(name: "", quantity: 1, unit: "g")
                        new.id = UUID()
                        sectionBinding.wrappedValue.ingredients.append(new)
                    }
                }) {
                    Label("Add Ingredient", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.wickedGreen)
                }
                .padding(.top, 4)
                
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Color.glindaPink)
                    TextField("Section Title (e.g., Cake)", text: sectionBinding.title)
                        .bold()
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if sections.count > 1 {
                        Button(action: {
                            withAnimation {
                                deleteSection(section.id)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
        
        Button(action: {
            withAnimation {
                sections.append(
                    RecipeSection(
                        title: "New Section",
                        ingredients: [Ingredient(name: "", quantity: 1, unit: "g")],
                        instructions: [""]
                    )
                )
            }
        }) {
            Text("Add New Section")
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.glindaPink)
        .listRowBackground(Color.black.opacity(0.2))
    }

    // MARK: - Bindings helpers

    private func binding(for sectionID: UUID) -> Binding<RecipeSection> {
        guard let idx = sections.firstIndex(where: { $0.id == sectionID }) else {
            return $sections[0]
        }
        return $sections[idx]
    }

    private func binding(for ingredientID: UUID, in sectionID: UUID) -> Binding<Ingredient>? {
        guard let sIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return nil }
        guard let iIndex = sections[sIndex].ingredients.firstIndex(where: { $0.id == ingredientID }) else { return nil }
        return $sections[sIndex].ingredients[iIndex]
    }

    // MARK: - Mutations

    private func deleteSection(_ sectionID: UUID) {
        if let idx = sections.firstIndex(where: { $0.id == sectionID }) {
            sections.remove(at: idx)
        }
    }

    private func deleteIngredient(ingredientID: UUID, in sectionID: UUID) {
        withAnimation {
            guard let sIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
            if let iIndex = sections[sIndex].ingredients.firstIndex(where: { $0.id == ingredientID }) {
                sections[sIndex].ingredients.remove(at: iIndex)
            }
        }
    }

    private func moveIngredients(in sectionID: UUID, from indices: IndexSet, to newOffset: Int) {
        guard let sIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[sIndex].ingredients.move(fromOffsets: indices, toOffset: newOffset)
    }
}

private struct FlatIngredientsContent: View {
    @Binding var ingredients: [Ingredient]
    let units: [String]

    var body: some View {
        ForEach(ingredients) { ingredient in
            if let ingredientBinding = binding(for: ingredient.id) {
                IngredientRowEditor(
                    ingredient: ingredientBinding,
                    units: units,
                    onDelete: {
                        deleteIngredient(id: ingredient.id)
                    }
                )
            }
        }
        .onMove { indices, newOffset in
            ingredients.move(fromOffsets: indices, toOffset: newOffset)
        }

        Button(action: {
            withAnimation {
                var new = Ingredient(name: "", quantity: 1, unit: "g")
                new.id = UUID()
                ingredients.append(new)
            }
        }) {
            Label("Add Ingredient", systemImage: "plus.circle")
                .font(.subheadline)
                .foregroundStyle(Color.wickedGreen)
        }
        .listRowBackground(Color.black.opacity(0.2))
    }

    private func binding(for id: UUID) -> Binding<Ingredient>? {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return nil }
        return $ingredients[index]
    }

    private func deleteIngredient(id: UUID) {
        withAnimation {
            if let index = ingredients.firstIndex(where: { $0.id == id }) {
                ingredients.remove(at: index)
            }
        }
    }
}

struct IngredientsSection: View {
    @Binding var sections: [RecipeSection]
    @Binding var useSections: Bool
    
    let units = ["g", "ml", "cups", "Tbsp", "tsp", "pinch", "piece", "package", "can"]

    var body: some View {
        Section(header: HStack {
            Text("Ingredients")
            Spacer()
            Toggle("Sections", isOn: $useSections)
                .tint(SwiftUI.Color.wickedGreen)
                .labelsHidden()
            Text("Sections").font(.caption).foregroundStyle(.gray)
        }) {
            if useSections {
                SectionalIngredientsContent(sections: $sections, units: units)
            } else {
                if !sections.isEmpty {
                    FlatIngredientsContent(ingredients: $sections[0].ingredients, units: units)
                } else {
                    // Fallback to create a section if none exists
                    Button("Add your first ingredient") {
                        sections = [RecipeSection(title: "Main Ingredients", ingredients: [Ingredient(name: "", quantity: 1, unit: "g")], instructions: [""])]
                    }
                }
            }
        }
        .headerProminence(.increased)
        .listRowSeparatorTint(Color.white.opacity(0.3))
    }
}
