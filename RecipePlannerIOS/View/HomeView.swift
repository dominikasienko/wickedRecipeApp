//
// HomeView.swift
// RecipePlannerIOS
//
// Created by Dominika Sieńko on 30/11/2025.
//

import SwiftUI
import FirebaseAuth
import Observation

struct HomeView: View {
    @Environment(ProfileManager.self) private var profileManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(AuthManager.self) private var authManager

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var filteredRecipesList: [Recipe] = []

    @State private var dailyInspirationsList: [Recipe] = []

    var recipesSource: [Recipe] {
        return recipeManager.userRecipes
    }

    /// Calculates and sets the daily inspiration list (max 5 unique recipes).
    private func refreshDailyInspirations() {
        let shuffled = recipesSource.shuffled()
        var uniqueRecipes: [Recipe] = []
        var addedIDs: Set<String> = []

        for recipe in shuffled {
            if let id = recipe.id, addedIDs.count < 5, !addedIDs.contains(id) {
                uniqueRecipes.append(recipe)
                addedIDs.insert(id)
            }
        }
        dailyInspirationsList = uniqueRecipes
    }

    var staticCategories: [String] {
        let categories = [
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
        return categories
    }

// MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = proxy.safeAreaInsets

            ZStack {
                Color.darkBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.wickedGreen.opacity(0.3), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                ).ignoresSafeArea()
                RadialGradient(
                    colors: [Color.glindaPink.opacity(0.15), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 500
                ).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {

                        SearchFieldView(searchText: $searchText)

                        if searchText.isEmpty {
                            DailyInspirationSection(recipes: dailyInspirationsList)
                        }

                        CategoriesSection(
                            selectedCategory: $selectedCategory,
                            dynamicCategories: staticCategories
                        )
                        
                        AllRecipesSection(
                            recipes: filteredRecipesList,
                            selectedCategory: selectedCategory
                        )
                    }
                    .padding(.top, safeAreaInsets.top + 70)
                    .padding(.bottom, 20)
                }
                .edgesIgnoringSafeArea(.top)

                VStack(spacing: 0) {
                    HStack {
                        NavigationLink(destination: ProfileView()) {
                            HStack {
                                AsyncImage(url: URL(string: profileManager.userProfile?.profileImageURL ?? "")) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundStyle(Color.glindaPink)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())

                                let fullName = "\(profileManager.userProfile?.firstName ?? "User") \(profileManager.userProfile?.lastName ?? "")"
                                Text(fullName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        NavigationLink(destination: AddRecipeView()) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.wickedGreen)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .padding(.top, safeAreaInsets.top + 10)
                }
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.2)), alignment: .bottom)
                .frame(maxHeight: .infinity, alignment: .top)
                .edgesIgnoringSafeArea(.top)
            }
            .task {
                guard let userId = authManager.user?.uid else { return }
                if recipeManager.userRecipes.isEmpty {
                    try? await recipeManager.fetchUserRecipes(userId: userId)
                }
                refreshDailyInspirations()
                updateFilteredRecipes()
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .onAppear {
                updateFilteredRecipes()
            }
            .onChange(of: searchText) {
                updateFilteredRecipes()
            }
            .onChange(of: selectedCategory) {
                updateFilteredRecipes()
            }
            .onChange(of: recipeManager.userRecipes) {
                refreshDailyInspirations()
                updateFilteredRecipes()
            }
        }
    }

// MARK: - Filter logic

    private func updateFilteredRecipes() {
        var recipes = recipesSource

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lowercasedSearch = searchText.lowercased()
            recipes = recipes.filter { recipe in
                let nameMatch = recipe.name.lowercased().contains(lowercasedSearch)
                let categoryMatch = recipe.category.lowercased().contains(lowercasedSearch)

                let ingredientText = recipe.ingredients.map { ingredient in
                    let qty = ingredient.quantity
                    let qtyText = qty.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", qty)
                        : String(format: "%.2f", qty)
                    return "\(ingredient.name) \(qtyText) \(ingredient.unit)"
                }
                .joined(separator: " ")
                .lowercased()
                let ingredientMatch = ingredientText.contains(lowercasedSearch)

                return nameMatch || categoryMatch || ingredientMatch
            }
        }

        if let category = selectedCategory {
            let normalizedSelected = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            recipes = recipes.filter { recipe in
                let recipeCat = recipe.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return recipeCat == normalizedSelected
            }
        }

        self.filteredRecipesList = recipes
    }
}

// MARK: Helper Views

struct SearchFieldView: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.glindaPink.opacity(0.8))

            TextField(String(localized: "Search by name or ingredients..."), text: $searchText)
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .tint(Color.wickedGreen)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct DailyInspirationSection: View {
    let recipes: [Recipe]

    var body: some View {
        VStack(alignment: .leading) {
            Text(String(localized: "Daily inspiration"))
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    if recipes.isEmpty {
                        Text(String(localized: "Add recipes to see inspirations."))
                            .padding()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recipes) { recipe in
                        RecipeCard(recipe: recipe)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - CategoriesSection

struct CategoriesSection: View {
    @Binding var selectedCategory: String?
    var dynamicCategories: [String]

    private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    init(selectedCategory: Binding<String?>, dynamicCategories: [String]) {
        self._selectedCategory = selectedCategory
        self.dynamicCategories = dynamicCategories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(localized: "Categories"))
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: { selectedCategory = nil }) {
                    Text(String(localized: "ALL"))
                        .font(.subheadline).bold()
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(selectedCategory == nil ? Color.glindaPink : Color.white.opacity(0.15))
                        .foregroundStyle(selectedCategory == nil ? Color.darkBackground : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(dynamicCategories, id: \.self) { category in
                            if !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    selectedCategory = (selectedCategory?.uppercased() == category.uppercased()) ? nil : category
                                }) {
                                    Text(category.capitalized)
                                        .font(.subheadline).bold()
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(selectedCategory?.uppercased() == category.uppercased() ? Color.glindaPink : Color.white.opacity(0.15))
                                        .foregroundStyle(selectedCategory?.uppercased() == category.uppercased() ? Color.darkBackground : .white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}


struct AllRecipesSection: View {
    let recipes: [Recipe]
    let selectedCategory: String?

    var title: String {
        if let category = selectedCategory {
            return category.capitalized
        }
        return String(localized: "All recipes")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(title) (\(recipes.count))")
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            if recipes.isEmpty {
                ContentUnavailableView(
                    String(localized: "No recipes available"),
                    systemImage: "magnifyingglass",
                    description: Text(selectedCategory == nil ? String(localized: "Add your first recipe using the ‘plus’ button at the top.") : String(localized: "No recipes matching the selected category or search term."))
                )
                .padding()
                .foregroundStyle(.secondary)
            } else {
                let columns: [GridItem] = [GridItem(.flexible())]

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(recipes) { recipe in
                        RecipeGridItem(recipe: recipe)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: Recipe Cards

struct RecipeCard: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(AuthManager.self) private var authManager
    let recipe: Recipe

    var body: some View {
        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: recipe.imageURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Color.darkBackground.opacity(0.5)
                    } else {
                        Color.darkBackground.opacity(0.3)
                            .overlay(ProgressView())
                    }
                }
                .frame(width: 180, height: 250)
                .cornerRadius(15)
                .overlay(alignment: .topTrailing) {
                    HStack {
                        Text("\(recipe.preparationTimeMinutes) mins")
                            .font(.caption).bold()
                            .padding(6)
                            .background(.black.opacity(0.6))
                            .cornerRadius(10)

                        Button(action: {
                            Task {
                                guard let recipeId = recipe.id else { return }
                                try? await recipeManager.toggleFavorite(recipeId: recipeId)
                            }
                        }) {
                            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                                .padding(6)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                                .foregroundStyle(recipe.isFavorite ? Color.glindaPink : .white)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(8)
                }

                VStack(alignment: .leading) {
                    Text(recipe.name)
                        .font(.headline).bold()
                        .lineLimit(2)
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.glindaPink.opacity(0.8))

                        let authorName = (recipe.userId == authManager.user?.uid) ? (profileManager.userProfile?.firstName ?? String(localized: "You")) : String(localized: "Someone Else")
                        Text(String(localized: "By \(authorName)"))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.white)
                .padding()
                .frame(width: 180, alignment: .leading)
                .background(
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(15)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecipeGridItem: View {
    let recipe: Recipe

    var body: some View {
        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
            VStack(alignment: .leading, spacing: 0) {
                AsyncImage(url: URL(string: recipe.imageURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Color.darkBackground.opacity(0.3)
                            .overlay {
                                Image(systemName: "photo.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            }
                    } else {
                        Color.darkBackground.opacity(0.3)
                            .overlay(ProgressView())
                    }
                }
                .frame(height: 150)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.subheadline).bold()
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Text("\(recipe.preparationTimeMinutes) mins | \(recipe.category)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
