//
//  RecipeDetailView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseStorage
import FirebaseAuth

struct RecipeDetailView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    
    @State private var selectedTab: Int = 0
    @State private var detailNutritionResult: NutritionCalculationResult?
    @State private var isCalculatingNutrition = false
    @State private var nutritionInfoMessage: LocalizedStringKey?
    
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let nutritionCalculator = RecipeNutritionCalculator.shared
    
    private var currentRecipe: Recipe {
        guard let recipeId = recipe.id else { return recipe }
        return recipeManager.userRecipes.first(where: { $0.id == recipeId }) ?? recipe
    }
    
    private var storedNutritionResult: NutritionCalculationResult? {
        currentRecipe.nutrition?.asCalculationResult
    }
    
    private var displayedNutritionResult: NutritionCalculationResult? {
        storedNutritionResult ?? detailNutritionResult
    }
    
    private var shouldShowCalculateButton: Bool {
        storedNutritionResult == nil
    }

    init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    var body: some View {
        GeometryReader { proxy in
            detailContent(proxy: proxy)
        }
    }
    
    @ViewBuilder
    private func detailContent(proxy: GeometryProxy) -> some View {
        let safeTopInset = proxy.safeAreaInsets.top
        let displayedRecipe = currentRecipe
        
        ZStack(alignment: .top) {
            darkBackground.ignoresSafeArea()
            WickedAmbientGlowLayer(pinkOpacity: 0.3, greenOpacity: 0.4, pinkDiameter: 250)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let isScrollingDown = minY > safeTopInset
                        
                        AsyncImageView(urlString: displayedRecipe.imageURL ?? "")
                            .scaledToFill()
                            .frame(
                                width: geo.size.width,
                                height: 350 + (isScrollingDown ? (minY - safeTopInset) : 0)
                            )
                            .overlay(
                                LinearGradient(
                                    colors: [.black.opacity(0.3), .clear, .black.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipped()
                            .offset(y: isScrollingDown ? -(minY - safeTopInset) : 0)
                    }
                    .frame(height: 350)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text(displayedRecipe.name)
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundStyle(wickedGreen)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        ViewThatFits {
                            HStack(spacing: 12) {
                                WickedInfoCapsule(
                                    icon: "clock.fill",
                                    text: "\(displayedRecipe.preparationTimeMinutes) min"
                                )
                                WickedInfoCapsule(
                                    icon: "person.2.fill",
                                    text: "\(displayedRecipe.servings) servings"
                                )
                                WickedInfoCapsule(
                                    icon: "tag.fill",
                                    text: AppOptionCatalog.localizedTitle(
                                        for: displayedRecipe.category,
                                        in: AppOptionCatalog.recipeCategories
                                    )
                                )
                                Spacer(minLength: 0)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    WickedInfoCapsule(
                                        icon: "clock.fill",
                                        text: "\(displayedRecipe.preparationTimeMinutes) min"
                                    )
                                    WickedInfoCapsule(
                                        icon: "person.2.fill",
                                        text: "\(displayedRecipe.servings) servings"
                                    )
                                }
                                WickedInfoCapsule(
                                    icon: "tag.fill",
                                    text: AppOptionCatalog.localizedTitle(
                                        for: displayedRecipe.category,
                                        in: AppOptionCatalog.recipeCategories
                                    )
                                )
                            }
                        }
                        
                        Divider().overlay(glindaPink.opacity(0.5))

                        Picker("Details", selection: $selectedTab) {
                            Text("Ingredients").tag(0)
                            Text("Instructions").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedTab == 0 {
                            IngredientsLayout(
                                sections: displayedRecipe.sections ?? [],
                                ingredients: displayedRecipe.ingredients
                            )
                        } else {
                            InstructionsLayout(
                                sections: displayedRecipe.sections ?? [],
                                instructions: displayedRecipe.instructions
                            )
                        }
                        
                        if let notes = displayedRecipe.notes, !notes.isEmpty {
                            NotesSection(notes: notes)
                        }
                        
                        NutritionCalculationPanel(
                            result: displayedNutritionResult,
                            isCalculating: isCalculatingNutrition,
                            infoMessage: nutritionInfoMessage,
                            showCalculateButton: shouldShowCalculateButton,
                            onCalculate: calculateNutritionValues
                        )
                    }
                    .padding(25)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25, corners: [.topLeft, .topRight])
                    .padding(.top, -50)
                }
            }
            .ignoresSafeArea(.container, edges: .top)

        }
        .overlay(alignment: .top) {
            HStack {
                WickedGlassButton(icon: "chevron.backward", action: {
                    dismiss()
                })
                
                Spacer()
                
                WickedGlassButton(
                    icon: displayedRecipe.isFavorite ? "heart.fill" : "heart",
                    color: displayedRecipe.isFavorite ? glindaPink : .white,
                    action: {
                        toggleFavorite()
                    }
                )
                
                NavigationLink {
                    EditRecipeView(
                        recipe: displayedRecipe,
                        onRecipeDeleted: { dismiss() }
                    )
                        .navigationTitle("Edit recipe")
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, safeTopInset + 6)
            .zIndex(3)
        }
        .onAppear {
            let selectedColor = UIColor(Color(red: 0.0, green: 0.6, blue: 0.2))
            UISegmentedControl.appearance().selectedSegmentTintColor = selectedColor
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
            UISegmentedControl.appearance().backgroundColor = UIColor(white: 0.1, alpha: 0.3)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func toggleFavorite() {
        Task {
            guard let recipeId = currentRecipe.id else { return }
            try? await recipeManager.toggleFavorite(recipeId: recipeId)
        }
    }
    
    private var ingredientsForNutrition: [Ingredient] {
        let sectionIngredients = (currentRecipe.sections ?? []).flatMap { $0.ingredients }
        return sectionIngredients.isEmpty ? currentRecipe.ingredients : sectionIngredients
    }
    
    private func calculateNutritionValues() {
        guard !isCalculatingNutrition else { return }
        guard shouldShowCalculateButton else { return }
        
        isCalculatingNutrition = true
        nutritionInfoMessage = nil
        
        let ingredients = ingredientsForNutrition
        let servings = currentRecipe.servings
        let relatedRecipes = recipeManager.userRecipes
        let currentRecipeID = currentRecipe.id
        let currentRecipeName = currentRecipe.name
        
        Task {
            let result = await nutritionCalculator.calculate(
                ingredients: ingredients,
                servings: servings,
                relatedRecipes: relatedRecipes,
                currentRecipeId: currentRecipeID,
                currentRecipeName: currentRecipeName
            )
            
            var persistenceError: LocalizedStringKey?
            if result.totalIngredients > 0 {
                if let recipeId = currentRecipeID {
                    do {
                        try await recipeManager.updateRecipeNutrition(
                            recipeId: recipeId,
                            nutrition: result.toStoredNutrition()
                        )
                    } catch {
                        persistenceError = AppLocalization.key( "Values were calculated, but could not be saved yet.")
                    }
                } else {
                    persistenceError = AppLocalization.key( "Values were calculated locally. Save the recipe first to keep them.")
                }
            }
            
            await MainActor.run {
                detailNutritionResult = result
                isCalculatingNutrition = false
                
                if let persistenceError {
                    nutritionInfoMessage = persistenceError
                } else if result.totalIngredients == 0 {
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
}

// MARK: - Widok Składników

struct IngredientsLayout: View {
    let sections: [RecipeSection]
    let ingredients: [Ingredient]
    
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !sections.isEmpty {
                ForEach(sections) { section in
                    if !section.ingredients.isEmpty {
                        SectionHeader(title: section.title)
                        IngredientList(ingredients: section.ingredients, glindaPink: glindaPink)
                    }
                }
            } else {
                IngredientList(ingredients: ingredients, glindaPink: glindaPink)
            }
        }
    }
}

private struct IngredientList: View {
    @Environment(\.locale) private var locale
    let ingredients: [Ingredient]
    let glindaPink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ingredients, id: \.id) { ingredient in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.dotted")
                        .font(.caption)
                        .foregroundStyle(glindaPink)
                    
                    Text(ingredient.name)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        Text(IngredientQuantityFormatter.formatted(ingredient.quantity, locale: locale))
                        Text(verbatim: " \(ingredient.unit)")
                    }
                        .foregroundStyle(.white.opacity(0.7))
                        .bold()
                        .lineLimit(1)
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Widok Instrukcji

struct InstructionsLayout: View {
    let sections: [RecipeSection]
    let instructions: [String]
    
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !sections.isEmpty {
                ForEach(sections) { section in
                    if !section.instructions.isEmpty {
                        SectionHeader(title: section.title)
                        InstructionList(instructions: section.instructions, glindaPink: glindaPink)
                    }
                }
            } else {
                InstructionList(instructions: instructions, glindaPink: glindaPink)
            }
        }
    }
}

private struct InstructionList: View {
    let instructions: [String]
    let glindaPink: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(instructions.indices, id: \.self) { index in
                if !instructions[index].isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .bold()
                            .foregroundStyle(glindaPink)
                        
                        Text(instructions[index])
                            .foregroundStyle(.white)
                            .lineSpacing(5)
                    }
                }
            }
        }
    }
}

// MARK: - Widok Nagłówka Sekcji

private struct SectionHeader: View {
    let title: String
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider().overlay(glindaPink.opacity(0.5))
            
            Text(title)
                .font(.title3).bold()
                .foregroundStyle(wickedGreen)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }
}

// MARK: - Widoki Pomocnicze

struct WickedInfoCapsule: View {
    let icon: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct WickedGlassButton: View {
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .foregroundStyle(color)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct NotesSection: View {
    let notes: String
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(glindaPink.opacity(0.5))
            
            Text("Comments")
                .font(.title2).bold()
                .foregroundStyle(glindaPink)
            
            Text(notes)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(5)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
