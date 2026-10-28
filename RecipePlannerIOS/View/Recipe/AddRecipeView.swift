//
//  AddRecipeView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import PhotosUI

struct AddRecipeView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(\.locale) private var locale
    @Environment(AuthManager.self) private var authManager
    @Environment(StorageManager.self) private var storageManager

    @State private var name: String = ""
    @State private var category: String = "LUNCH & DINNER"
    @State private var prepTime: Int = 30
    @State private var servings: Int = 4
    @State private var notes: String = ""
    @State private var sections: [RecipeSection] = [
        RecipeSection(
            title: "Ingredients & Steps",
            ingredients: [Ingredient(name: "", quantity: 0, unit: "g")],
            instructions: [""]
        )
    ]
    
    @State private var useSections: Bool = false
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage: LocalizedStringKey = AppLocalization.key("The recipe could not be saved. Check your connection or permissions.")
    
    @Environment(\.dismiss) var dismiss

    private var availableCategories: [AppLocalizedOption] {
        AppOptionCatalog.recipeCategories.sorted {
            $0.resolvedTitle(locale: locale).localizedCaseInsensitiveCompare(
                $1.resolvedTitle(locale: locale)
            ) == .orderedAscending
        }
    }

    private var isFormValid: Bool {
        guard !name.isEmpty else { return false }
        
        let allIngredients = sections.flatMap { $0.ingredients }.filter { !$0.name.isEmpty && $0.quantity >= 0 }
        let allInstructions = sections.flatMap { $0.instructions }.filter { !$0.isEmpty }
        
        return !allIngredients.isEmpty && !allInstructions.isEmpty
    }

// MARK: - View Body

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            WickedAmbientGlowLayer(pinkOpacity: 0.3, greenOpacity: 0.4)
                .ignoresSafeArea()

            List {
                Section {
                    RecipeImagePicker(selectedImage: $selectedImage)
                        .onTapGesture {
                            isShowingImagePicker = true
                        }
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .headerProminence(.increased)
                
                Section("General Information") {
                    NativeTextField(
                        text: $name,
                        placeholder: "Recipe Name",
                        autocorrectionType: .default,
                        autocapitalizationType: .words
                    )
                    .listRowBackground(Color.black.opacity(0.2))
                    
                    Picker("Category", selection: $category) {
                        ForEach(availableCategories) { category in
                            Text(category.title).tag(category.id)
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                    
                    HStack {
                        Text("Preparation Time")
                        Spacer()
                        Stepper("\(prepTime) min", value: $prepTime, in: 5...240, step: 5)
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                    
                    HStack {
                        Text("Number of Servings")
                        Spacer()
                        Stepper("\(servings)", value: $servings, in: 1...32)
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                IngredientsSection(sections: $sections, useSections: $useSections)
                    .listRowSeparatorTint(Color.white.opacity(0.3))
                InstructionsSection(sections: $sections, useSections: $useSections)
                    .listRowSeparatorTint(Color.white.opacity(0.3))
                
                Section("Notes / Tips (Optional)") {
                    NativeTextView(text: $notes)
                        .frame(minHeight: 100)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
                .listRowBackground(Color.black.opacity(0.2))
                .foregroundStyle(.white)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                Section {
                    Button("Save Recipe") {
                        Task {
                            await saveRecipe()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.wickedGreen)
                    .disabled(!isFormValid)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            }
            .scrollContentBackground(.hidden)
            .listStyle(.grouped)
            .wickedReadableWidth(900)
            
        }
        .navigationTitle("Add Recipe")
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, isPresented: $isShowingImagePicker)
        }
        .alert("Saving Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }
    
// MARK: - Save Function
    
    private func saveRecipe() async {
        guard let userId = authManager.user?.uid else {
            print("SAVE ERROR: No user UID.")
            saveErrorMessage = AppLocalization.key( "The recipe could not be saved. Check your connection or permissions.")
            showingSaveError = true
            return
        }
        
        let cleanedSections = sections
            .map { section in
                var cleaned = section
                cleaned.ingredients = cleaned.ingredients.filter { !$0.name.isEmpty && $0.quantity >= 0 }
                cleaned.instructions = cleaned.instructions.filter { !$0.isEmpty }
                return cleaned
            }
            .filter { !$0.ingredients.isEmpty || !$0.instructions.isEmpty }
        
        let flatIngredients = cleanedSections.flatMap { $0.ingredients }
        let flatInstructions = cleanedSections.flatMap { $0.instructions }
        
        guard !flatIngredients.isEmpty && !flatInstructions.isEmpty else {
            print("SAVE ERROR: Ingredients or Instructions are empty after cleanup.")
            saveErrorMessage = AppLocalization.key( "The recipe could not be saved. Check your connection or permissions.")
            showingSaveError = true
            return
        }
        
        let finalSections: [RecipeSection]?
        if useSections || cleanedSections.count > 1 {
            finalSections = cleanedSections
        } else {
            finalSections = nil
        }
        
        let newRecipe = Recipe(
            userId: userId,
            name: name,
            category: category,
            preparationTimeMinutes: prepTime,
            servings: servings,
            ingredients: flatIngredients,
            instructions: flatInstructions,
            sections: finalSections,
            notes: notes.isEmpty ? nil : notes,
            imageURL: nil,
            dateAdded: Date(),
            isFavorite: false
        )
        
        do {
            let saved = try await recipeManager.saveRecipe(
                recipe: newRecipe,
                newImage: selectedImage,
                existingImageURL: nil,
                storageManager: storageManager
            )
            
            print("Recipe saved successfully! ID: \(saved.id ?? "unknown")")
            dismiss()
        } catch {
            let nsError = error as NSError
            print("FATAL ERROR IN RECORDING THE RECIPE [\(nsError.domain):\(nsError.code)]: \(nsError.localizedDescription)")
            saveErrorMessage = AppLocalization.key("The recipe could not be saved. Check your connection or permissions.")
            showingSaveError = true
        }
    }
}
