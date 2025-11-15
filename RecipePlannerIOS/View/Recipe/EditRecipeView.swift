//
//  EditRecipeView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import PhotosUI

struct EditRecipeView: View {
    // 1. Environment Objects
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) var dismiss
    
    // 2. Original Recipe (read-only)
    let originalRecipe: Recipe
    
    // 3. Local State, initialized with existing recipe
    @State private var recipeToEdit: Recipe
    @State private var selectedImage: UIImage?
    @State private var originalImageURL: String?
    
    // Image Tracking States
    @State private var imageWasChanged: Bool = false
    @State private var imageWasRemoved: Bool = false
    @State private var isShowingImagePicker = false
    
    // Alert States
    @State private var showingSaveError = false
    @State private var showingDeleteConfirmation = false

    // Available categories (as in AddRecipeView)
    let availableCategories: [String] = [
        "ALL", "BASICS", "BREAKFAST & BRUNCH", "APPETIZERS, SIDES & SALADS",
        "SOUP, STEW & CURRY", "LUNCH & DINNER", "PASTA & GNOCCHI",
        "QUICK & EASY", "PIZZA, SANDWICHES & BURGER", "CAKE",
        "FINGERFOOD & SNACKS", "SWEETS & DESSERT"
    ]
    
    // Formatters
    private var timeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimum = 1
        return formatter
    }()
    
    private var quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // Form Validation
    private var isFormValid: Bool {
        return !recipeToEdit.name.isEmpty && recipeToEdit.preparationTimeMinutes > 0
    }
    
    // MARK: - Initialization
    
    init(recipe: Recipe) {
        self.originalRecipe = recipe
        _recipeToEdit = State(initialValue: recipe)
        _originalImageURL = State(initialValue: recipe.imageURL)
        // Set up appearance for UIKit elements if needed (e.g., Segmented Control)
        // Since we are using Form, we rely mostly on SwiftUI styles.
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // 1. Background (Dark Background Color)
            Color.darkBackground.ignoresSafeArea()
            
            // --- WICKED V2: Colorful Background Blobs ---
            // Using predefined Color extension (must be added outside this struct)
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.4))
                .frame(width: 300, height: 300)
                .position(x: 50, y: 200)
                .blur(radius: 100)
                .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.glindaPink.opacity(0.3))
                .frame(width: 250, height: 250)
                .position(x: 350, y: 700)
                .blur(radius: 80)
                .ignoresSafeArea()

            // 2. Form Content (Glass Effect)
            // Using a List/Form with a custom background for the glass look
            
            List {
                Section("Basic Information") {
                    TextField("Recipe Name", text: $recipeToEdit.name)
                        .autocorrectionDisabled()
                        .listRowBackground(Color.black.opacity(0.2)) // Frosted Glass effect
                        .foregroundStyle(.white)
                    
                    Picker("Category", selection: $recipeToEdit.category) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                    
                    HStack {
                        Text("Prep Time (minutes)")
                        Spacer()
                        TextField("Time", value: $recipeToEdit.preparationTimeMinutes, formatter: timeFormatter)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.white)
                    
                    Toggle("Favorite", isOn: $recipeToEdit.isFavorite)
                        .listRowBackground(Color.black.opacity(0.2))
                        .tint(Color.wickedGreen)
                        .foregroundStyle(.white)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3)) // Subtle separator

                // --- INGREDIENTS SECTION ---
                Section("Ingredients") {
                    ForEach($recipeToEdit.ingredients) { $ingredient in
                        HStack {
                            TextField("Name", text: $ingredient.name)
                                .autocorrectionDisabled()
                            Spacer()
                            TextField("Amount", value: $ingredient.quantity, formatter: quantityFormatter)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            TextField("Unit", text: $ingredient.unit)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        .listRowBackground(Color.black.opacity(0.2))
                        .foregroundStyle(.white)
                    }
                    .onDelete(perform: deleteIngredient)
                    
                    Button("Add Ingredient") {
                        recipeToEdit.ingredients.append(Ingredient(name: "", quantity: 0.0, unit: "g"))
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(Color.wickedGreen)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // --- INSTRUCTIONS SECTION ---
                Section("Instructions (Steps)") {
                    ForEach(recipeToEdit.instructions.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            Text("Step \(index + 1):")
                                .font(.caption).bold()
                                .foregroundStyle(Color.glindaPink)
                            TextEditor(text: $recipeToEdit.instructions[index])
                                .frame(minHeight: 80)
                                .border(Color.gray.opacity(0.3))
                                .scrollContentBackground(.hidden) // Required to show custom background
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .listRowBackground(Color.black.opacity(0.2))
                        .foregroundStyle(.white)
                    }
                    .onDelete(perform: deleteInstruction)
                    
                    Button("Add Step") {
                        recipeToEdit.instructions.append("")
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(Color.wickedGreen)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // --- IMAGE SECTION ---
                Section("Recipe Image") {
                    VStack {
                        // Display Current Image
                        ImageDisplayView(selectedImage: $selectedImage, imageURL: recipeToEdit.imageURL)
                        
                        HStack {
                            Button("Select Image") {
                                isShowingImagePicker = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.wickedGreen)
                            
                            if selectedImage != nil || recipeToEdit.imageURL != nil {
                                Button("Remove Image") {
                                    selectedImage = nil
                                    recipeToEdit.imageURL = nil
                                    imageWasRemoved = true
                                    imageWasChanged = true
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .frame(maxWidth: .infinity)
                }
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))
                
                // --- DELETE SECTION ---
                Section {
                    Button("Delete Recipe", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                    .foregroundStyle(.red)
                }
                
            } // End List
            .scrollContentBackground(.hidden) // Important for transparent/custom background
            .listStyle(.grouped) // Use grouped style for sections
            .preferredColorScheme(.dark)
            .padding(.top, 1) // Small padding fix for list background drawing
            
        } // End ZStack
        .onAppear {
            originalImageURL = originalRecipe.imageURL
        }
        .navigationTitle("Edit Recipe")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await handleUpdateRecipe()
                    }
                }
                .disabled(!isFormValid)
                // Use a custom color for the Save button
                .foregroundStyle(isFormValid ? Color.wickedGreen : Color.gray)
            }
        }
        .confirmationDialog("Are you sure you want to delete this recipe?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteRecipe()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Operation Error", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The operation could not be completed. Please try again later.")
        }
        // Image Picker Sheet
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, imageWasChanged: $imageWasChanged)
                .onDisappear {
                    if imageWasChanged {
                        imageWasRemoved = false
                    }
                }
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteIngredient(offsets: IndexSet) {
        recipeToEdit.ingredients.remove(atOffsets: offsets)
    }
    
    private func deleteInstruction(offsets: IndexSet) {
        recipeToEdit.instructions.remove(atOffsets: offsets)
    }
    
    // MARK: - Actions
    
    private func handleUpdateRecipe() async {
        guard isFormValid, let recipeId = originalRecipe.id else { return }
        
        // Clean up empty fields before saving
        recipeToEdit.ingredients = recipeToEdit.ingredients.filter { !$0.name.isEmpty }
        recipeToEdit.instructions = recipeToEdit.instructions.filter { !$0.isEmpty }

        do {
            try await recipeManager.updateRecipe(
                recipeId: recipeId,
                updatedRecipe: recipeToEdit,
                newImage: selectedImage,
                storageManager: storageManager
            )
            dismiss()
        } catch {
            print("UPDATE ERROR: \(error.localizedDescription)")
            showingSaveError = true
        }
    }
    
    private func handleDeleteRecipe() async {
        guard let recipeId = originalRecipe.id else { return }
        
        do {
            try await recipeManager.deleteRecipe(
                recipeId: recipeId,
                imageURL: originalRecipe.imageURL,
                storageManager: storageManager
            )
            dismiss()
        } catch {
            print("Error while deleting: \(error.localizedDescription)")
            showingSaveError = true
        }
    }
}

// MARK: - Supporting Views

// Helper View for Image Display Logic
struct ImageDisplayView: View {
    @Binding var selectedImage: UIImage?
    var imageURL: String?
    
    var body: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 250)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.vertical)
        } else if let urlString = imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable()
                case .failure:
                    Text("Image not found")
                @unknown default:
                    EmptyView()
                }
            }
            .scaledToFit()
            .frame(maxHeight: 250)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.vertical)
        }
    }
}


// ImagePicker remains the same (provided in the original code)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var imageWasChanged: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.imageWasChanged = true
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
