//
//  IngredientsSection.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/12/2025.
//

import SwiftUI

private struct IngredientQuantityField: View {
    @Environment(\.locale) private var locale
    @Binding var quantity: Double
    @State private var text: String

    init(quantity: Binding<Double>) {
        _quantity = quantity
        _text = State(initialValue: IngredientQuantityField.formatted(quantity.wrappedValue, locale: .autoupdatingCurrent))
    }

    var body: some View {
        TextField("Qty", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .frame(width: 64)
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(5)
            .onAppear {
                text = IngredientQuantityField.formatted(quantity, locale: locale)
            }
            .onChange(of: locale.identifier) {
                text = IngredientQuantityField.formatted(quantity, locale: locale)
            }
            .onChange(of: text) { _, newValue in
                let sanitized = IngredientQuantityFormatter.sanitizedInput(newValue, locale: locale)
                if sanitized != newValue {
                    text = sanitized
                    return
                }

                if sanitized.isEmpty {
                    quantity = 0
                    return
                }

                if let parsedValue = IngredientQuantityFormatter.parsedInput(sanitized, locale: locale) {
                    quantity = parsedValue
                }
            }
            .onChange(of: quantity) { _, newValue in
                guard !text.isEmpty else { return }
                let formattedValue = IngredientQuantityFormatter.formatted(newValue, locale: locale)
                if text != formattedValue, IngredientQuantityFormatter.parsedInput(text, locale: locale) != newValue {
                    text = formattedValue
                }
            }
    }

    private static func formatted(_ value: Double, locale: Locale) -> String {
        IngredientQuantityFormatter.formatted(value, locale: locale)
    }
}

private struct IngredientRowEditor: View {
    @Binding var ingredient: Ingredient
    let units: [String]
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IngredientQuantityField(quantity: $ingredient.quantity)
            
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
            NativeTextField(
                text: $ingredient.name,
                placeholder: "Ingredient",
                autocorrectionType: .default,
                autocapitalizationType: .sentences
            )
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
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(section.ingredients) { ingredient in
                    if let ingredientBinding = ingredientBinding(for: ingredient.id, in: section.id) {
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
                        appendIngredient(to: section.id)
                    }
                }) {
                    HStack {
                        Spacer()
                        Label("Add Ingredient", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.wickedGreen)
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
                
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Color.glindaPink)
                    if let titleBinding = titleBinding(for: section.id) {
                        NativeTextField(
                            text: titleBinding,
                            placeholder: "Section Title (e.g., Cake)",
                            autocorrectionType: .default,
                            autocapitalizationType: .words
                        )
                        .fontWeight(.bold)
                    }
                    
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
        .buttonStyle(.borderless)
        .foregroundStyle(Color.glindaPink)
        .listRowBackground(Color.black.opacity(0.2))
    }

    // MARK: - Bindings helpers

    private func titleBinding(for sectionID: UUID) -> Binding<String>? {
        guard sections.contains(where: { $0.id == sectionID }) else {
            return nil
        }

        return Binding(
            get: {
                sections.first(where: { $0.id == sectionID })?.title ?? ""
            },
            set: { newValue in
                guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
                sections[index].title = newValue
            }
        )
    }

    private func ingredientBinding(for ingredientID: UUID, in sectionID: UUID) -> Binding<Ingredient>? {
        guard let section = sections.first(where: { $0.id == sectionID }),
              section.ingredients.contains(where: { $0.id == ingredientID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let section = sections.first(where: { $0.id == sectionID }),
                      let ingredient = section.ingredients.first(where: { $0.id == ingredientID }) else {
                    return Ingredient(id: ingredientID, name: "", quantity: 1, unit: "g")
                }
                return ingredient
            },
            set: { newValue in
                guard let sIndex = sections.firstIndex(where: { $0.id == sectionID }),
                      let iIndex = sections[sIndex].ingredients.firstIndex(where: { $0.id == ingredientID }) else { return }
                sections[sIndex].ingredients[iIndex] = newValue
            }
        )
    }

    // MARK: - Mutations

    private func deleteSection(_ sectionID: UUID) {
        if let idx = sections.firstIndex(where: { $0.id == sectionID }) {
            sections.remove(at: idx)
        }
    }

    private func appendIngredient(to sectionID: UUID) {
        guard let sIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[sIndex].ingredients.append(
            Ingredient(id: UUID(), name: "", quantity: 1, unit: "g")
        )
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
            HStack {
                Spacer()
                Label("Add Ingredient", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.wickedGreen)
                Spacer()
            }
        }
        .buttonStyle(.borderless)
        .listRowBackground(Color.black.opacity(0.2))
    }

    private func binding(for id: UUID) -> Binding<Ingredient>? {
        guard ingredients.contains(where: { $0.id == id }) else { return nil }

        return Binding(
            get: {
                ingredients.first(where: { $0.id == id }) ?? Ingredient(id: id, name: "", quantity: 1, unit: "g")
            },
            set: { newValue in
                guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
                ingredients[index] = newValue
            }
        )
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

                    Button(action: {
                        withAnimation {
                            useSections = true
                            sections.append(
                                RecipeSection(
                                    title: "New Section",
                                    ingredients: [Ingredient(name: "", quantity: 1, unit: "g")],
                                    instructions: [""]
                                )
                            )
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Add New Section")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.glindaPink)
                    .listRowBackground(Color.black.opacity(0.2))
                } else {
                    // Fallback to create a section if none exists
                    Button("Add your first ingredient") {
                        sections = [RecipeSection(title: "Main Ingredients", ingredients: [Ingredient(name: "", quantity: 1, unit: "g")], instructions: [""])]
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .headerProminence(.increased)
        .listRowSeparatorTint(Color.white.opacity(0.3))
    }
}
