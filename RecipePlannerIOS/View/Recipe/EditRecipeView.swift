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

private enum EditRecipeAlert: Identifiable, Hashable {
    case confirmDeletion
    case saveFailed
    case deleteFailed
    case imageCleanupFailed

    var id: Self { self }
}

struct EditRecipeView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(\.locale) private var locale
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) var dismiss
    
    let originalRecipe: Recipe
    let onRecipeDeleted: (() -> Void)?
    
    // MARK: - State
    @State private var recipeToEdit: Recipe
    @State private var editableSections: [RecipeSection]
    @State private var useSections: Bool = false
    
    // Image Handling
    @State private var selectedImage: UIImage?
    @State private var imageWasChanged: Bool = false
    @State private var imageWasRemoved: Bool = false
    @State private var isShowingImagePicker = false
    
    // Alerts
    @State private var activeAlert: EditRecipeAlert?
    @State private var isSaving = false
    @State private var isDeleting = false

    // Nutrition
    @State private var nutritionResult: NutritionCalculationResult?
    @State private var isCalculatingNutrition = false
    @State private var nutritionInfoMessage: LocalizedStringKey?
    private let nutritionCalculator = RecipeNutritionCalculator.shared

    private var availableCategories: [AppLocalizedOption] {
        var categories = AppOptionCatalog.recipeCategories

        let currentCategory = recipeToEdit.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentCategory.isEmpty && !categories.contains(where: { $0.id == currentCategory }) {
            categories.append(AppLocalizedOption(id: currentCategory, localizationKey: currentCategory))
        }

        return categories.sorted {
            $0.resolvedTitle(locale: locale).localizedCaseInsensitiveCompare(
                $1.resolvedTitle(locale: locale)
            ) == .orderedAscending
        }
    }
    
    private var timeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimum = 1
        return formatter
    }()
    
    // MARK: - Initialization
    init(recipe: Recipe, onRecipeDeleted: (() -> Void)? = nil) {
        self.originalRecipe = recipe
        self.onRecipeDeleted = onRecipeDeleted
        
        var initialRecipe = recipe
        initialRecipe.category = AppOptionCatalog.canonicalValue(
            for: initialRecipe.category,
            in: AppOptionCatalog.recipeCategories
        )
        
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
        _editableSections = State(initialValue: initialRecipe.sections ?? [])
        _useSections = State(initialValue: isSectional)
        _nutritionResult = State(initialValue: initialRecipe.nutrition?.asCalculationResult)
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        guard !recipeToEdit.name.trimmingCharacters(in: .whitespaces).isEmpty,
              recipeToEdit.preparationTimeMinutes > 0 else { return false }
        
        let sectionsToCheck = editableSections
        
        let hasIngredients = sectionsToCheck.contains { section in
            section.ingredients.contains { !$0.name.isEmpty }
        }
        
        let hasInstructions = sectionsToCheck.contains { section in
            section.instructions.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
            
        return hasIngredients && hasInstructions
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
                    NativeTextField(
                        text: $recipeToEdit.name,
                        placeholder: "Recipe Name",
                        autocorrectionType: .no,
                        autocapitalizationType: .words
                    )
                    
                    Picker("Category", selection: $recipeToEdit.category) {
                        ForEach(availableCategories) { category in
                            Text(category.title).tag(category.id)
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
                IngredientsSection(sections: $editableSections, useSections: $useSections)
                    .listRowSeparatorTint(Color.white.opacity(0.3))
                    .listRowBackground(customListRowBackground)
                
                InstructionsSection(sections: $editableSections, useSections: $useSections)
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
                        
                        NativeTextView(text: $recipeToEdit.notes.bound)
                            .frame(minHeight: 100)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .listRowBackground(customListRowBackground)
                .foregroundStyle(.white)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))

                // MARK: Nutrition
                Section("Nutrition") {
                    NutritionCalculationPanel(
                        result: nutritionResult,
                        isCalculating: isCalculatingNutrition,
                        infoMessage: nutritionInfoMessage,
                        onCalculate: calculateNutritionValues
                    )
                }
                .listRowBackground(customListRowBackground)
                .foregroundStyle(.white)
                .headerProminence(.increased)
                .listRowSeparatorTint(Color.white.opacity(0.3))
                
                // MARK: Delete Button
                Section {
                    Button("Delete Recipe", role: .destructive) {
                        activeAlert = .confirmDeletion
                    }
                    .disabled(isSaving || isDeleting)
                    .listRowBackground(customListRowBackground)
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.grouped)
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
                .disabled(!isFormValid || isSaving || isDeleting)
                .foregroundStyle(isFormValid && !isSaving ? Color.wickedGreen : Color.gray)
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .confirmDeletion:
                Alert(
                    title: Text("Delete \(1) recipe?"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        Task { await handleDeleteRecipe() }
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            case .saveFailed:
                Alert(
                    title: Text("Operation Error"),
                    message: Text("The operation could not be completed. Please try again later."),
                    dismissButton: .default(Text("OK"))
                )
            case .deleteFailed:
                Alert(
                    title: Text("Operation Error"),
                    message: Text("The recipe could not be deleted. Check your connection and try again."),
                    dismissButton: .default(Text("OK"))
                )
            case .imageCleanupFailed:
                Alert(
                    title: Text("Operation Error"),
                    message: Text("The recipe was deleted, but its image could not be removed."),
                    dismissButton: .default(Text("OK")) {
                        if let onRecipeDeleted {
                            onRecipeDeleted()
                        } else {
                            dismiss()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, imageWasChanged: $imageWasChanged)
                .onDisappear {
                    if imageWasChanged && selectedImage != nil {
                        imageWasRemoved = false
                    }
                }
        }
        .onChange(of: recipeToEdit.servings) { _, _ in
            invalidateNutritionResult()
        }
        .onChange(of: editableSections) { _, _ in
            invalidateNutritionResult()
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    ProgressView("Deleting…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .zIndex(10)
            }
        }
    }
    
    // MARK: - Actions

    private func handleUpdateRecipe() async {
        guard isFormValid, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
            
        var finalRecipe = recipeToEdit
        var sectionsToProcess = editableSections

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
            
            finalRecipe.sections = nil
            finalRecipe.ingredients = flatIngredients
            finalRecipe.instructions = flatInstructions
        }

        finalRecipe.notes = finalRecipe.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            ? nil
            : finalRecipe.notes
        
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
            let nsError = error as NSError
            print("UPDATE ERROR [\(nsError.domain):\(nsError.code)]: \(nsError.localizedDescription)")
            activeAlert = .saveFailed
        }
    }
    
    private func handleDeleteRecipe() async {
        guard !isDeleting, !isSaving else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let result = try await recipeManager.deleteRecipe(
                recipe: originalRecipe,
                storageManager: storageManager
            )
            if result.imageCleanupFailures > 0 {
                activeAlert = .imageCleanupFailed
            } else {
                if let onRecipeDeleted {
                    onRecipeDeleted()
                } else {
                    dismiss()
                }
            }
        } catch {
            print("Error while deleting: \(error.localizedDescription)")
            activeAlert = .deleteFailed
        }
    }

    private var ingredientsForNutrition: [Ingredient] {
        let sectionIngredients = editableSections.flatMap { $0.ingredients }
        return sectionIngredients.isEmpty ? recipeToEdit.ingredients : sectionIngredients
    }

    private func calculateNutritionValues() {
        guard !isCalculatingNutrition else { return }

        isCalculatingNutrition = true
        nutritionInfoMessage = nil

        let ingredients = ingredientsForNutrition
        let servings = recipeToEdit.servings
        let relatedRecipes = recipeManager.userRecipes
        let currentRecipeID = recipeToEdit.id
        let currentRecipeName = recipeToEdit.name

        Task {
            let result = await nutritionCalculator.calculate(
                ingredients: ingredients,
                servings: servings,
                relatedRecipes: relatedRecipes,
                currentRecipeId: currentRecipeID,
                currentRecipeName: currentRecipeName
            )

            await MainActor.run {
                nutritionResult = result
                isCalculatingNutrition = false
                recipeToEdit.nutrition = result.totalIngredients > 0 ? result.toStoredNutrition() : nil

                if result.totalIngredients == 0 {
                    nutritionInfoMessage = AppLocalization.key( "Add ingredients with quantities first.")
                } else if result.matchedIngredients == 0 {
                    nutritionInfoMessage = AppLocalization.key( "No matching nutrition records were found.")
                } else if !result.missingIngredients.isEmpty {
                    nutritionInfoMessage = AppLocalization.key( "Some ingredients were not matched. Values are based on available data.")
                } else {
                    nutritionInfoMessage = nil
                }
            }
        }
    }

    private func invalidateNutritionResult() {
        if nutritionResult != nil {
            nutritionResult = nil
            recipeToEdit.nutrition = nil
            nutritionInfoMessage = AppLocalization.key( "Recipe changed. Tap calculate again to refresh values.")
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
