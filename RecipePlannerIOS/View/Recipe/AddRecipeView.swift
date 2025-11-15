// AddRecipeView.swift
import SwiftUI
import UIKit
import FirebaseAuth

struct AddRecipeView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(AuthManager.self) private var authManager
    @Environment(StorageManager.self) private var storageManager

    @State private var name: String = ""
    @State private var category: String = "LUNCH & DINNER"
    @State private var prepTime: Int = 30
    @State private var servings: Int = 4
    @State private var notes: String = ""
    @State private var instructions: [String] = [""]
    @State private var ingredients: [Ingredient] = [Ingredient(name: "", quantity: 0, unit: "g")]

    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var showingSaveError = false
    
    @Environment(\.dismiss) var dismiss

    let availableCategories: [String] = [
        "BASICS", "BREAKFAST & BRUNCH", "APPETIZERS, SIDES & SALADS",
        "SOUP, STEW & CURRY", "LUNCH & DINNER", "PASTA & GNOCCHI",
        "CAKE", "SWEETS & DESSERT", "FINGERFOOD & SNACKS", "QUICK & EASY",
        "PIZZA, SANDWICHES & BURGER", "INTERNATIONAL CUISINE", "VEGAN", "VEGETARIAN"
    ].sorted()

    private var isFormValid: Bool {
        !name.isEmpty &&
        !ingredients.filter { !$0.name.isEmpty }.isEmpty &&
        !instructions.filter { !$0.isEmpty }.isEmpty
    }

    // MARK: - View Body (Wicked Glass Implementation)

    var body: some View {
        ZStack {
            // 1. Background (Dark Background Color + Blobs)
            Color.darkBackground.ignoresSafeArea()
            
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.4))
                .frame(width: 300, height: 300)
                .position(x: 50, y: 50)
                .blur(radius: 100)
                .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.glindaPink.opacity(0.3))
                .frame(width: 250, height: 250)
                .position(x: 350, y: 750)
                .blur(radius: 80)
                .ignoresSafeArea()

            // 2. Form/List Content (Glass Effect)
            List {
                // 1. IMAGE SECTION
                Section {
                    RecipeImagePicker(selectedImage: $selectedImage)
                        .onTapGesture {
                            isShowingImagePicker = true
                        }
                        // Usunięcie domyślnego wcięcia dla Listy, aby zdjęcie było od krawędzi
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .headerProminence(.increased)
                
                // 2. GENERAL INFORMATION
                Section("General Information") {
                    TextField("Recipe Name", text: $name)
                        .listRowBackground(Color.black.opacity(0.2))
                        .foregroundStyle(.white)
                    
                    Picker("Category", selection: $category) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(category)
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
                        Stepper("\(servings)", value: $servings, in: 1...20)
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // 3. INGREDIENTS
                IngredientsSection1(ingredients: $ingredients)
                
                // 4. INSTRUCTIONS
                InstructionsSection1(instructions: $instructions)
                
                // 5. NOTES
                Section("Notes / Tips (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
                .listRowBackground(Color.black.opacity(0.2))
                .foregroundStyle(.white)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // 6. SAVE BUTTON
                Section {
                    Button("Save Recipe") {
                        Task {
                            await saveRecipe()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    // Zmiana koloru tinty na Wicked Green
                    .tint(Color.wickedGreen)
                    .disabled(!isFormValid)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            } // End List
            .scrollContentBackground(.hidden)
            .listStyle(.grouped)
            .preferredColorScheme(.dark)
            
        } // End ZStack
        .navigationTitle("Add Recipe")
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, isPresented: $isShowingImagePicker)
        }
        .alert("Saving Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The recipe could not be saved. Check your connection or permissions.")
        }
    }
    
    // MARK: - Save Function (Unchanged)
    
    private func saveRecipe() async {
        guard let userId = authManager.user?.uid else {
            print("SAVE ERROR: No user UID.")
            return
        }
        
        let newRecipe = Recipe(
            userId: userId,
            name: name,
            category: category,
            preparationTimeMinutes: prepTime,
            servings: servings,
            ingredients: ingredients.filter { !$0.name.isEmpty },
            instructions: instructions.filter { !$0.isEmpty },
            notes: notes.isEmpty ? nil : notes,
            imageURL: nil,
            dateAdded: Date(),
            isFavorite: false
        )
        
        do {
            try await recipeManager.saveNewRecipe(recipe: newRecipe, image: selectedImage, storageManager: storageManager)
            print("Recipe saved successfully!")
            dismiss()
        } catch {
            print("FATAL ERROR IN RECORDING THE RECIPE: \(error)")
            showingSaveError = true
        }
    }
}

// MARK: Dodatkowe komponenty potrzebne do kompilacji:


// C) IngredientsSection (Dostosowany do Glassmorphismu)
struct IngredientsSection1: View {
    @Binding var ingredients: [Ingredient]
    let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        Section("Ingredients") {
            ForEach($ingredients) { $ingredient in
                HStack {
                    TextField("Name", text: $ingredient.name)
                    Spacer()
                    TextField("Qty", value: $ingredient.quantity, formatter: quantityFormatter)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    TextField("Unit", text: $ingredient.unit)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                .listRowBackground(Color.black.opacity(0.2))
                .foregroundStyle(.white)
            }
            .onDelete { ingredients.remove(atOffsets: $0) }
            
            Button("Add Ingredient") {
                ingredients.append(Ingredient(name: "", quantity: 0, unit: "g"))
            }
            .listRowBackground(Color.black.opacity(0.2))
            .foregroundStyle(Color.wickedGreen)
        }
        .headerProminence(.increased)
        .listRowSeparatorTint(Color.white.opacity(0.3))
    }
}

// D) InstructionsSection (Dostosowany do Glassmorphismu)
struct InstructionsSection1: View {
    @Binding var instructions: [String]
    
    var body: some View {
        Section("Instructions") {
            ForEach(instructions.indices, id: \.self) { index in
                VStack(alignment: .leading) {
                    Text("Step \(index + 1):")
                        .font(.caption).bold()
                        .foregroundStyle(Color.glindaPink)
                    TextEditor(text: $instructions[index])
                        .frame(minHeight: 80)
                        .border(Color.gray.opacity(0.3))
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
                .listRowBackground(Color.black.opacity(0.2))
                .foregroundStyle(.white)
            }
            .onDelete { instructions.remove(atOffsets: $0) }
            
            Button("Add Step") {
                instructions.append("")
            }
            .listRowBackground(Color.black.opacity(0.2))
            .foregroundStyle(Color.wickedGreen)
        }
        .headerProminence(.increased)
        .listRowSeparatorTint(Color.white.opacity(0.3))
    }
}
