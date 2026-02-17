//
//  EditRecipeView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/12/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import PhotosUI

private let customListRowBackground = Color(uiColor: .black.withAlphaComponent(0.2))

struct EditRecipeView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) var dismiss
    
    let originalRecipe: Recipe
    
    // MARK: - State
    @State private var recipeToEdit: Recipe
    @State private var useSections: Bool = false
    
    // Image Handling
    @State private var selectedImage: UIImage?
    @State private var imageWasChanged: Bool = false
    @State private var imageWasRemoved: Bool = false
    @State private var isShowingImagePicker = false
    
    // Alerts
    @State private var showingSaveError = false
    @State private var showingDeleteConfirmation = false

    let availableCategories: [String] = [
        String(localized: "BASICS"),
        String(localized: "BREAKFAST & BRUNCH"),
        String(localized: "APPETIZERS, SIDES & SALADS"),
        String(localized: "SOUP, STEW & CURRY"),
        String(localized: "LUNCH & DINNER"),
        String(localized: "PASTA & GNOCCHI"),
        String(localized: "QUICK & EASY"),
        String(localized: "PIZZA, SANDWICHES & BURGER"),
        String(localized: "CAKE"),
        String(localized: "FINGERFOOD & SNACKS"),
        String(localized: "SWEETS & DESSERT")
    ].sorted()
    
    private var timeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimum = 1
        return formatter
    }()
    
    // MARK: - Initialization
    init(recipe: Recipe) {
        self.originalRecipe = recipe
        
        var initialRecipe = recipe
        
        if initialRecipe.sections == nil || initialRecipe.sections!.isEmpty {
            let initialSection = RecipeSection(
                title: "",
                ingredients: initialRecipe.ingredients,
                instructions: initialRecipe.instructions
            )
            initialRecipe.sections = [initialSection]
        }
        
        let isSectional = initialRecipe.sections!.count > 1 ||
                         (initialRecipe.sections!.count == 1 && !initialRecipe.sections![0].title.isEmpty)
        
        _recipeToEdit = State(initialValue: initialRecipe)
        _useSections = State(initialValue: isSectional)
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        guard !recipeToEdit.name.trimmingCharacters(in: .whitespaces).isEmpty,
              recipeToEdit.preparationTimeMinutes > 0 else { return false }
        
        let sectionsToCheck = recipeToEdit.sections ?? []
        
        let hasIngredients = sectionsToCheck.contains { section in
            section.ingredients.contains { !$0.name.isEmpty }
        }
        
        let hasInstructions = sectionsToCheck.contains { section in
            section.instructions.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
            
        return hasIngredients && hasInstructions
    }
    
    private var sectionsBinding: Binding<[RecipeSection]> {
        Binding(
            get: { recipeToEdit.sections ?? [] },
            set: { recipeToEdit.sections = $0 }
        )
    }
    
    // MARK: - View Body
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
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

            List {
                // MARK: Image Section
                Section {
                    VStack {
                        EditableRecipeImagePicker(
                            selectedImage: $selectedImage,
                            originalImageURL: imageWasRemoved ? nil : recipeToEdit.imageURL
                        )
                        .onTapGesture {
                            isShowingImagePicker = true
                        }
                        .contextMenu {
                            Button {
                                isShowingImagePicker = true
                            } label: {
                                Label("Change Photo", systemImage: "photo")
                            }
                            
                            if selectedImage != nil || (recipeToEdit.imageURL != nil && !imageWasRemoved) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        selectedImage = nil
                                        imageWasRemoved = true
                                        imageWasChanged = true
                                    }
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // MARK: Basic Info
                Section("Basic Information") {
                    TextField("Recipe Name", text: $recipeToEdit.name)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    
                    Picker("Category", selection: $recipeToEdit.category) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .foregroundStyle(.white)
                    
                    HStack {
                        Text("Prep Time (minutes)")
                        Spacer()
                        TextField("Time", value: $recipeToEdit.preparationTimeMinutes, formatter: timeFormatter)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    .foregroundStyle(.white)
                    
                    HStack {
                        Text("Number of Servings")
                        Spacer()
                        Stepper("\(recipeToEdit.servings)", value: $recipeToEdit.servings, in: 1...32)
                    }
                    .foregroundStyle(.white)
                    
                    Toggle("Favorite", isOn: $recipeToEdit.isFavorite)
                        .tint(Color.wickedGreen)
                        .foregroundStyle(.white)
                }
                .listRowBackground(customListRowBackground)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // MARK: Ingredients & Instructions
                IngredientsSection(sections: sectionsBinding, useSections: $useSections)
                    .listRowSeparatorTint(Color.white.opacity(0.3))
                    .listRowBackground(customListRowBackground)
                
                InstructionsSection(sections: sectionsBinding, useSections: $useSections)
                    .listRowSeparatorTint(Color.white.opacity(0.3))
                    .listRowBackground(customListRowBackground)
                
                // MARK: Notes
                Section("Notes / Tips (Optional)") {
                    ZStack(alignment: .topLeading) {
                        if recipeToEdit.notes.isEmptyOrNil {
                            Text("Add notes, tips, or storage instructions...")
                                .foregroundStyle(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        
                        TextEditor(text: $recipeToEdit.notes.bound)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                    }
                }
                .listRowBackground(customListRowBackground)
                .foregroundStyle(.white)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))
                
                // MARK: Delete Button
                Section {
                    Button("Delete Recipe", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .listRowBackground(customListRowBackground)
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.grouped)
            .preferredColorScheme(.dark)
            .environment(\.editMode, .constant(.active))
        }
        .navigationTitle("Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await handleUpdateRecipe()
                    }
                }
                .disabled(!isFormValid)
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
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, imageWasChanged: $imageWasChanged)
                .onDisappear {
                    if imageWasChanged && selectedImage != nil {
                        imageWasRemoved = false
                    }
                }
        }
    }
    
    // MARK: - Actions

    private func handleUpdateRecipe() async {
        guard isFormValid else { return }
            
        var finalRecipe = recipeToEdit
        var sectionsToProcess = finalRecipe.sections ?? []

        // Clean data: Remove empty rows
        sectionsToProcess = sectionsToProcess.map { section in
            var cleaned = section
            cleaned.ingredients = section.ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            cleaned.instructions = section.instructions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return cleaned
        }.filter { !$0.ingredients.isEmpty || !$0.instructions.isEmpty }

        if useSections {
            finalRecipe.sections = sectionsToProcess
            finalRecipe.ingredients = sectionsToProcess.flatMap { $0.ingredients }
            finalRecipe.instructions = sectionsToProcess.flatMap { $0.instructions }
        } else {
            let flatIngredients = sectionsToProcess.flatMap { $0.ingredients }
            let flatInstructions = sectionsToProcess.flatMap { $0.instructions }
            
            finalRecipe.sections = [RecipeSection(title: "", ingredients: flatIngredients, instructions: flatInstructions)]
            finalRecipe.ingredients = flatIngredients
            finalRecipe.instructions = flatInstructions
        }
        
        // Image Logic
        let newImageToUpload: UIImage? = (imageWasChanged && !imageWasRemoved) ? selectedImage : nil
        let existingImageURL = originalRecipe.imageURL
        
        if imageWasRemoved {
            finalRecipe.imageURL = nil
        } else if !imageWasChanged {
            finalRecipe.imageURL = originalRecipe.imageURL
        }
            
        do {
            finalRecipe.id = originalRecipe.id
            
            _ = try await recipeManager.saveRecipe(
                recipe: finalRecipe,
                newImage: newImageToUpload,
                existingImageURL: existingImageURL,
                storageManager: storageManager
            )
            dismiss()
        } catch {
            print("UPDATE ERROR: \(error.localizedDescription)")
            showingSaveError = true
        }
    }
    
    private func handleDeleteRecipe() async {
        do {
            try await recipeManager.deleteRecipe(
                recipe: originalRecipe,
                storageManager: storageManager
            )
            dismiss()
        } catch {
            print("Error while deleting: \(error.localizedDescription)")
            showingSaveError = true
        }
    }
}

// MARK: - Reusable Image UI Component

struct EditableRecipeImagePicker: View {
    @Binding var selectedImage: UIImage?
    var originalImageURL: String?

    private let imageHeight: CGFloat = 220
    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                    .clipped()
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            }
            else if let urlString = originalImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                            .clipped()
                            .cornerRadius(cornerRadius)
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            }
            else {
                placeholderView
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Label("Tap to change", systemImage: "camera.fill")
                        .font(.footnote)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }
            }
        }
        .contentShape(Rectangle())
        .animation(.default, value: selectedImage)
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.08))
                .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Tap to add a photo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Photo Picker Implementation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var imageWasChanged: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        self?.parent.selectedImage = uiImage
                        self?.parent.imageWasChanged = true
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

extension Binding where Value == String? {
    var bound: Binding<String> {
        return Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
}
