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
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.locale) private var locale

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var filteredRecipesList: [Recipe] = []

    @State private var dailyInspirationsList: [Recipe] = []
    @State private var selectionState = RecipeSelectionState()
    @State private var isDeletingSelectedRecipes = false
    @State private var activeRecipeAlert: HomeRecipeAlert?

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

    var staticCategories: [AppLocalizedOption] {
        AppOptionCatalog.recipeCategories.sorted {
            $0.resolvedTitle(locale: locale).localizedCaseInsensitiveCompare(
                $1.resolvedTitle(locale: locale)
            ) == .orderedAscending
        }
    }

// MARK: - Body

    var body: some View {
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
                        DailyInspirationSection(
                            recipes: dailyInspirationsList,
                            isSelectionMode: selectionState.isActive,
                            selectedRecipeIDs: selectionState.selectedRecipeIDs,
                            onSelect: toggleSelection,
                            onBeginSelection: beginSelection
                        )
                    }

                    CategoriesSection(
                        selectedCategory: $selectedCategory,
                        dynamicCategories: staticCategories
                    )
                    
                    AllRecipesSection(
                        recipes: filteredRecipesList,
                        selectedCategory: selectedCategory,
                        isSelectionMode: selectionState.isActive,
                        selectedRecipeIDs: selectionState.selectedRecipeIDs,
                        onSelect: toggleSelection,
                        onBeginSelection: beginSelection
                    )
                }
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                activeTopBar
            }
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
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .alert(item: $activeRecipeAlert, content: makeAlert(for:))
        .overlay {
            if isDeletingSelectedRecipes {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    ProgressView("Deleting…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectionState.isActive)
        .onAppear {
            updateFilteredRecipes()
        }
        .onChange(of: searchText) { _, _ in
            exitSelectionMode()
            updateFilteredRecipes()
        }
        .onChange(of: selectedCategory) { _, _ in
            exitSelectionMode()
            updateFilteredRecipes()
        }
        .onChange(of: locale.identifier) { _, _ in
            updateFilteredRecipes()
        }
        .onChange(of: authManager.user?.uid) { _, _ in
            exitSelectionMode()
        }
        .onChange(of: recipeManager.userRecipes) { _, newRecipes in
            refreshDailyInspirations()
            updateFilteredRecipes()
            let currentUserID = authManager.user?.uid
            var ownedIDs = Set<String>()
            for recipe in newRecipes {
                guard recipe.userId == currentUserID, let id = recipe.id else { continue }
                ownedIDs.insert(id)
            }
            selectionState.retain(validRecipeIDs: ownedIDs)
        }
    }

    @ViewBuilder
    private var activeTopBar: some View {
        if selectionState.isActive {
            selectionTopBar
        } else {
            homeTopBar
        }
    }

    private var selectionTopBar: some View {
        HStack(spacing: 12) {
            Button {
                exitSelectionMode()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.glindaPink)
            }
            .accessibilityLabel(Text("Cancel"))

            Spacer(minLength: 4)

            Text("\(selectionState.selectedRecipeIDs.count) recipes selected")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.updatesFrequently)

            Spacer(minLength: 4)

            Button {
                activeRecipeAlert = .confirmation(
                    recipeIDs: selectionState.selectedRecipeIDs.sorted()
                )
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
            }
            .disabled(selectionState.selectedRecipeIDs.isEmpty || isDeletingSelectedRecipes)
            .opacity(selectionState.selectedRecipeIDs.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.2))
        }
    }

    private var homeTopBar: some View {
        HStack {
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 10) {
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
                    
                    let fullName = "\(profileManager.userProfile?.firstName ?? AppLocalization.resolved("User", locale: locale)) \(profileManager.userProfile?.lastName ?? "")"
                    Text(fullName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            NavigationLink(destination: AddRecipeView()) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.wickedGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.2)),
            alignment: .bottom
        )
    }

// MARK: - Filter logic

    private func updateFilteredRecipes() {
        var recipes = recipesSource

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lowercasedSearch = searchText.lowercased()
            recipes = recipes.filter { recipe in
                let nameMatch = recipe.name.lowercased().contains(lowercasedSearch)
                let categoryMatch = [
                    recipe.category,
                    AppOptionCatalog.displayName(
                        for: recipe.category,
                        in: AppOptionCatalog.recipeCategories,
                        locale: locale
                    )
                ].contains { $0.lowercased().contains(lowercasedSearch) }

                let quantityFormatter = NumberFormatter()
                quantityFormatter.numberStyle = .decimal
                quantityFormatter.minimumFractionDigits = 0
                quantityFormatter.maximumFractionDigits = 2
                quantityFormatter.locale = locale
                let ingredientText = recipe.ingredients.map { ingredient in
                    let qtyText = quantityFormatter.string(from: NSNumber(value: ingredient.quantity)) ?? "\(ingredient.quantity)"
                    return "\(ingredient.name) \(qtyText) \(ingredient.unit)"
                }
                .joined(separator: " ")
                .lowercased()
                let ingredientMatch = ingredientText.contains(lowercasedSearch)

                return nameMatch || categoryMatch || ingredientMatch
            }
        }

        if let category = selectedCategory {
            recipes = recipes.filter { recipe in
                AppOptionCatalog.canonicalValue(
                    for: recipe.category,
                    in: AppOptionCatalog.recipeCategories
                ) == category
            }
        }

        self.filteredRecipesList = recipes
    }

    private func beginSelection(for recipe: Recipe) {
        guard recipe.userId == authManager.user?.uid, let recipeID = recipe.id else { return }
        selectionState.begin(selecting: recipeID)
    }

    private func toggleSelection(for recipe: Recipe) {
        guard recipe.userId == authManager.user?.uid, let recipeID = recipe.id else { return }
        selectionState.toggle(recipeID)
    }

    private func exitSelectionMode() {
        selectionState.exit()
    }

    private func makeAlert(for alert: HomeRecipeAlert) -> Alert {
        switch alert {
        case .confirmation(let recipeIDs):
            return Alert(
                title: Text("Delete \(recipeIDs.count) recipe?"),
                message: Text("This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await deleteRecipes(withIDs: recipeIDs) }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        case .deletionFailed:
            return Alert(
                title: Text("Operation Error"),
                message: Text("The operation could not be completed. Please try again later."),
                dismissButton: .default(Text("OK"))
            )
        case .partialDeletion:
            return Alert(
                title: Text("Operation Error"),
                message: Text("Some recipes were deleted, but the remaining selection could not be deleted. Check your connection and try again."),
                dismissButton: .default(Text("OK"))
            )
        case .partialDeletionWithImageCleanup:
            return Alert(
                title: Text("Operation Error"),
                message: Text("Some recipes were deleted, but image cleanup also failed. The remaining recipes are still selected."),
                dismissButton: .default(Text("OK"))
            )
        case .imageCleanupFailed:
            return Alert(
                title: Text("Operation Error"),
                message: Text("One or more recipe images could not be removed, but all selected recipes were deleted."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func deleteRecipes(withIDs recipeIDs: [String]) async {
        guard !isDeletingSelectedRecipes, !recipeIDs.isEmpty,
              let userID = authManager.user?.uid else { return }

        let requestedIDs = Set(recipeIDs)
        let recipesToDelete = recipeManager.userRecipes.filter {
            $0.userId == userID && $0.id.map(requestedIDs.contains) == true
        }
        guard recipesToDelete.count == requestedIDs.count else {
            activeRecipeAlert = .deletionFailed
            return
        }

        isDeletingSelectedRecipes = true
        defer { isDeletingSelectedRecipes = false }

        do {
            let result = try await recipeManager.deleteRecipes(
                recipes: recipesToDelete,
                storageManager: storageManager
            )
            selectionState.exit()
            if result.imageCleanupFailures > 0 {
                activeRecipeAlert = .imageCleanupFailed
            }
        } catch let error as RecipeDeletionError {
            if case .partialFailure(let imageCleanupFailures) = error {
                activeRecipeAlert = imageCleanupFailures > 0
                    ? .partialDeletionWithImageCleanup
                    : .partialDeletion
            } else {
                activeRecipeAlert = .deletionFailed
            }
        } catch {
            activeRecipeAlert = .deletionFailed
        }
    }
}

struct RecipeSelectionState: Equatable {
    private(set) var isActive = false
    private(set) var selectedRecipeIDs = Set<String>()

    mutating func begin(selecting recipeID: String) {
        isActive = true
        selectedRecipeIDs.insert(recipeID)
    }

    mutating func toggle(_ recipeID: String) {
        guard isActive else { return }
        if !selectedRecipeIDs.insert(recipeID).inserted {
            selectedRecipeIDs.remove(recipeID)
        }
    }

    mutating func exit() {
        isActive = false
        selectedRecipeIDs.removeAll()
    }

    mutating func retain(validRecipeIDs: Set<String>) {
        selectedRecipeIDs.formIntersection(validRecipeIDs)
        if selectedRecipeIDs.isEmpty {
            exit()
        }
    }
}

private enum HomeRecipeAlert: Identifiable {
    case confirmation(recipeIDs: [String])
    case deletionFailed
    case partialDeletion
    case partialDeletionWithImageCleanup
    case imageCleanupFailed

    var id: String {
        switch self {
        case .confirmation(let recipeIDs): "confirmation-\(recipeIDs.joined(separator: ","))"
        case .deletionFailed: "deletion-failed"
        case .partialDeletion: "partial-deletion"
        case .partialDeletionWithImageCleanup: "partial-deletion-image-cleanup"
        case .imageCleanupFailed: "image-cleanup-failed"
        }
    }
}

// MARK: Helper Views

struct SearchFieldView: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.glindaPink.opacity(0.8))

            TextField(AppLocalization.key( "Search by name or ingredients..."), text: $searchText)
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
    let isSelectionMode: Bool
    let selectedRecipeIDs: Set<String>
    let onSelect: (Recipe) -> Void
    let onBeginSelection: (Recipe) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(AppLocalization.key( "Daily inspiration"))
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    if recipes.isEmpty {
                        Text(AppLocalization.key( "Add recipes to see inspirations."))
                            .padding()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            isSelectionMode: isSelectionMode,
                            isSelected: recipe.id.map(selectedRecipeIDs.contains) ?? false,
                            onSelect: { onSelect(recipe) },
                            onBeginSelection: { onBeginSelection(recipe) }
                        )
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
    var dynamicCategories: [AppLocalizedOption]

    private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    init(selectedCategory: Binding<String?>, dynamicCategories: [AppLocalizedOption]) {
        self._selectedCategory = selectedCategory
        self.dynamicCategories = dynamicCategories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(AppLocalization.key( "Categories"))
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: { selectedCategory = nil }) {
                    Text(AppLocalization.key( "ALL"))
                        .font(.subheadline).bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(selectedCategory == nil ? Color.glindaPink : Color.white.opacity(0.15))
                        .foregroundStyle(selectedCategory == nil ? Color.darkBackground : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(dynamicCategories) { category in
                            if !category.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    selectedCategory = selectedCategory == category.id ? nil : category.id
                                }) {
                                    Text(category.title)
                                        .font(.subheadline).bold()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(selectedCategory == category.id ? Color.glindaPink : Color.white.opacity(0.15))
                                        .foregroundStyle(selectedCategory == category.id ? Color.darkBackground : .white)
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
    let isSelectionMode: Bool
    let selectedRecipeIDs: Set<String>
    let onSelect: (Recipe) -> Void
    let onBeginSelection: (Recipe) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            let categoryKey = selectedCategory.flatMap {
                AppOptionCatalog.localizationKey(for: $0, in: AppOptionCatalog.recipeCategories)
            }
            let title = categoryKey.map { LocalizedStringKey($0) }
                ?? LocalizedStringKey("All recipes")
            HStack(spacing: 0) {
                Text(title)
                Text(verbatim: " ")
                Text("(\(recipes.count))")
            }
                .font(.title2).bold()
                .foregroundStyle(Color.glindaPink)
                .padding(.horizontal)

            if recipes.isEmpty {
                ContentUnavailableView(
                    AppLocalization.key( "No recipes available"),
                    systemImage: "magnifyingglass",
                    description: Text(selectedCategory == nil ? AppLocalization.key( "Add your first recipe using the ‘plus’ button at the top.") : AppLocalization.key( "No recipes matching the selected category or search term."))
                )
                .padding()
                .foregroundStyle(.secondary)
            } else {
                let columns: [GridItem] = [GridItem(.flexible())]

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(recipes) { recipe in
                        RecipeGridItem(
                            recipe: recipe,
                            isSelectionMode: isSelectionMode,
                            isSelected: recipe.id.map(selectedRecipeIDs.contains) ?? false,
                            onSelect: { onSelect(recipe) },
                            onBeginSelection: { onBeginSelection(recipe) }
                        )
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
    @Environment(\.locale) private var locale
    let recipe: Recipe
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onBeginSelection: () -> Void

    private var authorName: String {
        if recipe.userId == authManager.user?.uid {
            return profileManager.userProfile?.firstName
                ?? AppLocalization.resolved("You", locale: locale)
        }
        return AppLocalization.resolved("Someone Else", locale: locale)
    }

    private var canSelect: Bool {
        recipe.userId == authManager.user?.uid && recipe.id != nil
    }

    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onSelect) {
                    cardFace
                }
                .accessibilityLabel(Text(isSelected ? "Deselect recipe" : "Select recipe"))
                .accessibilityValue(Text(recipe.name))
            } else {
                NavigationLink(value: recipe) {
                    cardFace
                }
                .highPriorityGesture(
                    LongPressGesture(minimumDuration: 0.45, maximumDistance: 18)
                        .onEnded { _ in
                            guard canSelect else { return }
                            onBeginSelection()
                        }
                )
                .accessibilityAction(named: Text("Select recipe")) {
                    guard canSelect else { return }
                    onBeginSelection()
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isSelectionMode {
                recipeSelectionIndicator
            } else {
                favoriteButton
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.wickedGreen, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var cardFace: some View {
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

            VStack(alignment: .leading) {
                Text(recipe.name)
                    .font(.headline).bold()
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.glindaPink.opacity(0.8))

                    Text(AppLocalization.key("By \(authorName)"))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .foregroundStyle(.white)
            .padding()
            .frame(width: 180, alignment: .leading)
            .background(
                LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(width: 180, height: 250)
        .overlay(alignment: .topTrailing) {
            Text("\(recipe.preparationTimeMinutes) mins")
                .font(.caption).bold()
                .lineLimit(1)
                .padding(6)
                .background(.black.opacity(0.6))
                .cornerRadius(10)
                .foregroundStyle(.white)
                .padding(8)
                .padding(.trailing, 38)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var favoriteButton: some View {
        Button {
            Task {
                guard let recipeId = recipe.id else { return }
                try? await recipeManager.toggleFavorite(recipeId: recipeId)
            }
        } label: {
            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                .padding(6)
                .background(.black.opacity(0.6))
                .clipShape(Circle())
                .foregroundStyle(recipe.isFavorite ? Color.glindaPink : .white)
        }
        .accessibilityLabel(Text(recipe.isFavorite ? "Remove from favorites" : "Add to favorites"))
        .padding(8)
    }

    private var recipeSelectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.semibold))
            .foregroundStyle(isSelected ? Color.darkBackground : Color.wickedGreen)
            .padding(5)
            .background(isSelected ? Color.wickedGreen : Color.black.opacity(0.72), in: Circle())
            .padding(8)
            .accessibilityHidden(true)
    }
}

struct RecipeGridItem: View {
    @Environment(\.locale) private var locale
    @Environment(AuthManager.self) private var authManager
    let recipe: Recipe
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onBeginSelection: () -> Void

    private var canSelect: Bool {
        recipe.userId == authManager.user?.uid && recipe.id != nil
    }

    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onSelect) {
                    cardFace
                }
                .accessibilityLabel(Text(isSelected ? "Deselect recipe" : "Select recipe"))
                .accessibilityValue(Text(recipe.name))
            } else {
                NavigationLink(value: recipe) {
                    cardFace
                }
                .highPriorityGesture(
                    LongPressGesture(minimumDuration: 0.45, maximumDistance: 18)
                        .onEnded { _ in
                            guard canSelect else { return }
                            onBeginSelection()
                        }
                )
                .accessibilityAction(named: Text("Select recipe")) {
                    guard canSelect else { return }
                    onBeginSelection()
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.darkBackground : Color.wickedGreen)
                    .padding(5)
                    .background(isSelected ? Color.wickedGreen : Color.black.opacity(0.72), in: Circle())
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.wickedGreen, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
    }

    private var cardFace: some View {
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.white)

                Text("\(recipe.preparationTimeMinutes) mins | \(AppOptionCatalog.displayName(for: recipe.category, in: AppOptionCatalog.recipeCategories, locale: locale))")
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
}
