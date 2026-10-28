//
//  MealPlannerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import SwiftUI
import FirebaseAuth

struct MealPlannerView: View {
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.locale) private var locale
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2
    
    @State private var currentMonthDate: Date = Date().startOfMonth
    @State private var selectedDate: Date = Date().startOfDay
    @State private var isShowingAddSheet = false
    @State private var isShowingShoppingList = false
    
    var availableRecipes: [Recipe] {
        recipeManager.userRecipes
    }
    
    var entriesForDay: [MealPlanEntry] {
        mealPlannerManager.entriesForDay(selectedDate)
    }

    private var recipesById: [String: Recipe] {
        Dictionary(
            uniqueKeysWithValues: recipeManager.userRecipes.compactMap { recipe in
                guard let id = recipe.id else { return nil }
                return (id, recipe)
            }
        )
    }

    private var nutritionSummary: DailyNutritionSummaryModel {
        DailyNutritionSummaryModel.make(
            for: entriesForDay,
            recipesById: recipesById,
            target: profileManager.userProfile?.calculateMacrosIfProfileComplete()
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                WickedAmbientGlowLayer(pinkOpacity: 0.2, greenOpacity: 0.3, pinkDiameter: 250, greenDiameter: 300)
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    Group {
                        if geometry.size.width >= 720 {
                            widePlannerLayout
                        } else {
                            compactPlannerLayout
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .navigationTitle("Meal Plan")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.darkBackground.opacity(0.5), for: .navigationBar)
            .sheet(isPresented: $isShowingAddSheet) {
                AddMealSheet(
                    selectedDate: selectedDate,
                    availableRecipes: availableRecipes
                )
            }
            .sheet(isPresented: $isShowingShoppingList) {
                ShoppingListView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingShoppingList = true
                    } label: {
                        Label("Shopping list", systemImage: "list.clipboard.fill")
                            .foregroundStyle(Color.wickedGreen)
                    }
                }
            }
            .task {
                if recipeManager.userRecipes.isEmpty, let userId = authManager.user?.uid {
                    try? await recipeManager.fetchUserRecipes(userId: userId)
                }
            }
        }
    }

    private var calendarCard: some View {
        VStack {
            MonthHeader(currentMonthDate: $currentMonthDate)

            CalendarGrid(
                currentMonthDate: currentMonthDate,
                selectedDate: $selectedDate,
                entries: mealPlannerManager.allMealPlanEntries,
                firstWeekday: weekStartDay
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    private var addMealButton: some View {
        Button("Add Meal") { isShowingAddSheet = true }
            .buttonStyle(.borderedProminent)
            .tint(.wickedGreen)
            .padding(.bottom, 10)
    }

    private var compactPlannerLayout: some View {
        Group {
            if verticalSizeClass == .compact {
                ScrollView { compactPlannerContent }
            } else {
                compactPlannerContent
            }
        }
    }

    private var compactPlannerContent: some View {
        VStack(spacing: 0) {
            calendarCard
                .padding(.horizontal)

            DailyMealsSection(
                selectedDate: selectedDate,
                entries: entriesForDay,
                nutritionSummary: nutritionSummary,
                usesOuterScrollView: verticalSizeClass == .compact
            )

            addMealButton
        }
        .wickedReadableWidth(760)
    }

    private var widePlannerLayout: some View {
        Group {
            if verticalSizeClass == .compact {
                ScrollView { widePlannerContent(fillsHeight: false) }
            } else {
                widePlannerContent(fillsHeight: true)
            }
        }
    }

    private func widePlannerContent(fillsHeight: Bool) -> some View {
        HStack(alignment: .top, spacing: 18) {
            calendarCard
                .frame(maxWidth: 360)

            VStack(spacing: 0) {
                DailyMealsSection(
                    selectedDate: selectedDate,
                    entries: entriesForDay,
                    nutritionSummary: nutritionSummary,
                    usesOuterScrollView: verticalSizeClass == .compact
                )
                .frame(maxHeight: fillsHeight ? .infinity : nil)

                addMealButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .wickedReadableWidth(1_280)
    }
}

// MARK: - Komponenty Kalendarza

struct MonthHeader: View {
    @Binding var currentMonthDate: Date
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Previous month"))
            Text(currentMonthDate, format: .dateTime.month(.wide).year())
                .font(.title2).bold()
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Next month"))
        }
        .padding(.bottom, 10)
    }
    
    private func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: currentMonthDate) {
            currentMonthDate = newDate.startOfMonth
        }
    }
}

struct CalendarGrid: View {
    @Environment(\.locale) private var locale
    let currentMonthDate: Date
    @Binding var selectedDate: Date
    let entries: [MealPlanEntry]
    let firstWeekday: Int
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        if (1...7).contains(firstWeekday) {
            calendar.firstWeekday = firstWeekday
        }
        return calendar
    }
    
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let shift = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return (0..<symbols.count).map { symbols[($0 + shift) % symbols.count] }
    }
    
    var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonthDate) else { return [] }
        let firstDayOfMonth = currentMonthDate.startOfMonth
        let startWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingSpaces = (startWeekday - calendar.firstWeekday + 7) % 7
        var daysArray: [Date?] = Array(repeating: nil, count: leadingSpaces)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                daysArray.append(date.startOfDay)
            }
        }
        return daysArray
    }
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption).bold()
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.bottom, 5)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        Button {
                            selectedDate = date
                        } label: {
                            DayCell(
                                date: date,
                                isSelected: date.isSameDay(as: selectedDate),
                                hasMeal: entries.contains(where: { $0.date.isSameDay(as: date) }),
                                isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonthDate, toGranularity: .month)
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(date, style: .date))
                        .accessibilityAddTraits(date.isSameDay(as: selectedDate) ? .isSelected : [])
                    } else {
                        Color.clear.frame(minHeight: 44)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let date: Date, isSelected: Bool, hasMeal: Bool, isCurrentMonth: Bool
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline).bold()
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.wickedGreen : Color.clear)
                .foregroundStyle(isSelected ? .black : (isCurrentMonth ? .white : .gray.opacity(0.5)))
                .clipShape(Circle())
                .overlay(
                    isToday ? Circle().stroke(Color.white.opacity(0.8), lineWidth: 1) : nil
                )
            
            Circle()
                .fill(hasMeal ? Color.glindaPink : Color.clear)
                .frame(width: 5, height: 5)
        }
    }
}

// MARK: - Sekcja Posiłków

private struct DailyMealsSection: View {
    let selectedDate: Date
    let entries: [MealPlanEntry]
    let nutritionSummary: DailyNutritionSummaryModel
    let usesOuterScrollView: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Meals for \(selectedDate, style: .date)")
                .font(.title2).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
            
            if usesOuterScrollView {
                mealRows
            } else {
                ScrollView { mealRows }
            }
        }
        .frame(maxHeight: usesOuterScrollView ? nil : .infinity)
    }

    private var mealRows: some View {
        VStack(spacing: 12) {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No meals planned", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("Tap 'Add Meal' to schedule a recipe for this day.")
                }
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            } else {
                ForEach(entries) { entry in
                    MealCard(entry: entry)
                }
            }

            DailyNutritionSummaryCard(summary: nutritionSummary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}

private struct DailyNutritionSummaryModel {
    let consumed: ConsumedNutritionTotals
    let target: UserProfile.Macros?
    let missingNutritionEntries: Int
    let missingRecipeEntries: Int
    let totalEntries: Int

    var skippedEntries: Int {
        missingNutritionEntries + missingRecipeEntries
    }

    static func make(
        for entries: [MealPlanEntry],
        recipesById: [String: Recipe],
        target: UserProfile.Macros?
    ) -> DailyNutritionSummaryModel {
        var totals = ConsumedNutritionTotals.zero
        var missingNutrition = 0
        var missingRecipe = 0

        for entry in entries {
            guard let recipe = recipesById[entry.recipeId] else {
                missingRecipe += 1
                continue
            }

            guard let nutrition = recipe.nutrition else {
                missingNutrition += 1
                continue
            }

            totals.add(nutrition: nutrition, servings: entry.plannedServings)
        }

        return DailyNutritionSummaryModel(
            consumed: totals,
            target: target,
            missingNutritionEntries: missingNutrition,
            missingRecipeEntries: missingRecipe,
            totalEntries: entries.count
        )
    }
}

private struct ConsumedNutritionTotals {
    var calories: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var protein: Double = 0

    static let zero = ConsumedNutritionTotals()

    mutating func add(nutrition: RecipeNutrition, servings: Int) {
        let multiplier = max(Double(servings), 0)
        guard multiplier > 0 else { return }

        calories += nutrition.caloriesPerServing * multiplier
        carbohydrates += nutrition.carbohydratesPerServing * multiplier
        fat += nutrition.fatPerServing * multiplier
        protein += nutrition.proteinPerServing * multiplier
    }
}

private struct DailyNutritionSummaryCard: View {
    @Environment(\.locale) private var locale
    let summary: DailyNutritionSummaryModel

    private var caloriesTarget: Double? {
        summary.target.map { Double($0.totalCalories) }
    }

    private var proteinRange: UserProfile.NutrientRange? {
        summary.target?.proteinG
    }

    private var carbsRange: UserProfile.NutrientRange? {
        summary.target?.carbsG
    }

    private var fatRange: UserProfile.NutrientRange? {
        summary.target?.fatG
    }

    private var skippedEntriesMessage: LocalizedStringKey {
        "\(summary.skippedEntries) planned meals could not be counted because nutrition data is missing."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily intake")
                    .font(.headline)
                    .foregroundStyle(Color.wickedGreen)

                Spacer()

                Text("\(formatNutritionValue(summary.consumed.calories, locale: locale)) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Divider().overlay(Color.glindaPink.opacity(0.45))

            if let caloriesTarget {
                MacroProgressRow(
                    title: AppLocalization.key("Estimated maintenance energy"),
                    consumed: summary.consumed.calories,
                    target: caloriesTarget,
                    unit: "kcal",
                    tint: .wickedGreen
                )
                Text(AppLocalization.key("This is a population estimate, not a prescribed calorie limit or weight-goal target."))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                NutritionSnapshotRows(summary: summary.consumed)
            }

            if let proteinRange, let carbsRange, let fatRange {
                MacroRangeProgressRow(
                    title: "Protein",
                    consumed: summary.consumed.protein,
                    range: proteinRange,
                    tint: .wickedBlue
                )

                MacroRangeProgressRow(
                    title: "Carbohydrates",
                    consumed: summary.consumed.carbohydrates,
                    range: carbsRange,
                    tint: .glindaPink
                )

                MacroRangeProgressRow(
                    title: "Fat",
                    consumed: summary.consumed.fat,
                    range: fatRange,
                    tint: .orange
                )
            } else {
                Text("Complete your profile and enable general estimates to see reference ranges.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let caloriesTarget {
                VStack(alignment: .leading, spacing: 4) {
                    let difference = summary.consumed.calories - caloriesTarget
                    Text(difference >= 0
                         ? AppLocalization.key("Above estimate by \(formatNutritionValue(difference, locale: locale)) kcal")
                         : AppLocalization.key("Below estimate by \(formatNutritionValue(abs(difference), locale: locale)) kcal"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, 4)
            }

            if summary.totalEntries > 0 && summary.skippedEntries > 0 {
                Divider().overlay(Color.white.opacity(0.18))
                Text(skippedEntriesMessage)
                    .font(.caption)
                    .foregroundStyle(Color.glindaPink.opacity(0.95))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

}

private struct NutritionSnapshotRows: View {
    let summary: ConsumedNutritionTotals

    var body: some View {
        VStack(spacing: 8) {
            NutritionSnapshotRow(
                title: "Protein",
                value: summary.protein,
                unit: "g"
            )
            NutritionSnapshotRow(
                title: "Carbohydrates",
                value: summary.carbohydrates,
                unit: "g"
            )
            NutritionSnapshotRow(
                title: "Fat",
                value: summary.fat,
                unit: "g"
            )
        }
    }
}

private struct NutritionSnapshotRow: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringKey
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text("\(formatNutritionValue(value, locale: locale)) \(unit)")
                .foregroundStyle(.white.opacity(0.85))
        }
        .font(.subheadline)
    }
}

private struct MacroProgressRow: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringKey
    let consumed: Double
    let target: Double
    let unit: String
    let tint: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return consumed / target
    }

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var difference: Double { consumed - target }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(formatNutritionValue(consumed, locale: locale)) / \(formatNutritionValue(target, locale: locale)) \(unit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(tint)
                        .frame(
                            width: max(4, proxy.size.width * normalizedProgress)
                        )
                }
            }
            .frame(height: 8)

            Text(difference >= 0
                 ? "Above estimate by \(formatNutritionValue(difference, locale: locale)) \(unit)"
                 : "Below estimate by \(formatNutritionValue(abs(difference), locale: locale)) \(unit)")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct MacroRangeProgressRow: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringKey
    let consumed: Double
    let range: UserProfile.NutrientRange
    let tint: Color

    private var progress: Double {
        guard range.upperGrams > 0 else { return 0 }
        return min(max(consumed / range.upperGrams, 0), 1)
    }

    private var status: LocalizedStringKey {
        if consumed < range.lowerGrams { return "Below the acceptable range" }
        if consumed > range.upperGrams { return "Above the acceptable range" }
        return "Within the acceptable range"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).foregroundStyle(.white)
                Spacer()
                Text("\(formatNutritionValue(consumed, locale: locale)) / \(formatNutritionValue(range.lowerGrams, locale: locale))–\(formatNutritionValue(range.upperGrams, locale: locale)) g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(4, proxy.size.width * progress))
                }
            }
            .frame(height: 8)

            Text(status)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private func formatNutritionValue(_ value: Double, locale: Locale) -> String {
    if value.isNaN || value.isInfinite {
        return "0"
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
    formatter.locale = locale
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

// MARK: KARTA POSIŁKU
struct MealCard: View {
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    let entry: MealPlanEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.localizedMealType)
                    .font(.caption.bold())
                    .foregroundStyle(Color.glindaPink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(entry.recipeName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            
            Spacer()
            
            Text("\(entry.plannedServings) serv.")
                .font(.callout)
                .foregroundStyle(.gray)
                .padding(.trailing, 10)
            
            Button(role: .destructive) {
                Task { try? await mealPlannerManager.deleteMealPlanEntry(entryId: entry.id ?? "") }
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Arkusz Dodawania Posiłku

private enum MealRecipeFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

struct AddMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(AuthManager.self) private var authManager
    @AppStorage("defaultMealType") private var defaultMealType: String = "breakfast"
    
    let selectedDate: Date
    let availableRecipes: [Recipe]
    
    @State private var selectedRecipe: Recipe?
    @State private var selectedMealType: String = "breakfast"
    @State private var recipeSearchText: String = ""
    @State private var activeRecipeFilter: MealRecipeFilter = .all
    @State private var errorMessage: LocalizedStringKey?
    
    @State private var plannedServings: Int = 1

    private var trimmedSearchText: String {
        recipeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSearchText: String {
        normalized(trimmedSearchText)
    }

    private var recipesById: [String: Recipe] {
        Dictionary(
            uniqueKeysWithValues: availableRecipes.compactMap { recipe in
                guard let id = recipe.id else { return nil }
                return (id, recipe)
            }
        )
    }

    private var overallRecentRecipeIDs: [String] {
        recentRecipeIDs(for: nil)
    }

    private var mealTypeRecentRecipeIDs: [String] {
        recentRecipeIDs(for: selectedMealType)
    }

    private var favoriteRecipes: [Recipe] {
        sortRecipes(availableRecipes.filter(\.isFavorite))
    }

    private var recentRecipes: [Recipe] {
        let ids = mealTypeRecentRecipeIDs.isEmpty ? overallRecentRecipeIDs : mealTypeRecentRecipeIDs
        return ids.compactMap { recipesById[$0] }
    }

    private var recommendedRecipes: [Recipe] {
        if !recentRecipes.isEmpty {
            return Array(recentRecipes.prefix(6))
        }

        if !favoriteRecipes.isEmpty {
            return Array(favoriteRecipes.prefix(6))
        }

        return Array(sortRecipes(availableRecipes).prefix(6))
    }

    private var filteredRecipes: [Recipe] {
        let baseRecipes: [Recipe]
        switch activeRecipeFilter {
        case .all:
            baseRecipes = sortRecipes(availableRecipes)
        case .favorites:
            baseRecipes = favoriteRecipes
        case .recent:
            baseRecipes = recentRecipes
        }

        guard !normalizedSearchText.isEmpty else { return baseRecipes }
        return baseRecipes.filter(matchesSearch)
    }

    private var browseTitle: LocalizedStringKey {
        if !trimmedSearchText.isEmpty {
            return "Search results"
        }

        switch activeRecipeFilter {
        case .all:
            return "Browse all recipes"
        case .favorites:
            return "Favorite recipes"
        case .recent:
            return "Recently planned"
        }
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            WickedAmbientGlowLayer(pinkOpacity: 0, greenOpacity: 0.3, greenDiameter: 200)
                .ignoresSafeArea()

            VStack {
                Text("Add Meal")
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 15) {
                            HStack {
                                Text("Date")
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(selectedDate, style: .date)
                                    .font(.headline)
                                    .foregroundStyle(Color.wickedGreen)
                            }
                            
                            Picker("Meal type", selection: $selectedMealType) {
                                ForEach(AppOptionCatalog.mealTypes) { meal in
                                    Text(meal.title).tag(meal.id)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(.wickedGreen)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recipe")
                                .font(.headline)
                                .foregroundStyle(.white)

                            MealRecipeSearchField(searchText: $recipeSearchText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(MealRecipeFilter.allCases) { filter in
                                        MealRecipeFilterChip(
                                            title: filter.title,
                                            systemImage: filter.systemImage,
                                            isSelected: activeRecipeFilter == filter
                                        ) {
                                            activeRecipeFilter = filter
                                        }
                                    }
                                }
                            }

                            if availableRecipes.isEmpty {
                                ContentUnavailableView {
                                    Label("No recipes available", systemImage: "fork.knife.circle")
                                } description: {
                                    Text("Add recipes first so you can plan them in your calendar.")
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.gray)
                            } else {
                                if activeRecipeFilter == .all && trimmedSearchText.isEmpty {
                                    if !favoriteRecipes.isEmpty {
                                        MealRecipeQuickSection(
                                            title: Text("Favorites"),
                                            recipes: Array(favoriteRecipes.prefix(6)),
                                            selectedRecipe: selectedRecipe,
                                            onSelect: selectRecipe
                                        )
                                    }

                                    if !recommendedRecipes.isEmpty {
                                        MealRecipeQuickSection(
                                            title: recentRecipes.isEmpty
                                                ? Text("Quick picks")
                                                : Text("Recent for \(AppOptionCatalog.displayName(for: selectedMealType, in: AppOptionCatalog.mealTypes, locale: locale))"),
                                            recipes: recommendedRecipes,
                                            selectedRecipe: selectedRecipe,
                                            onSelect: selectRecipe
                                        )
                                    }
                                }

                                HStack {
                                    Text(browseTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.glindaPink)

                                    Spacer()

                                    Text("\(filteredRecipes.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.65))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }

                                if filteredRecipes.isEmpty {
                                    VStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.glindaPink)

                                        Text("No recipes match your search.")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)

                                        if !trimmedSearchText.isEmpty {
                                            Button("Clear search") {
                                                recipeSearchText = ""
                                                activeRecipeFilter = .all
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(Color.wickedGreen)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(filteredRecipes) { recipe in
                                            MealRecipeSelectionRow(
                                                recipe: recipe,
                                                isSelected: isSelected(recipe),
                                                isRecommended: recentRecipes.prefix(3).contains(where: { recent in
                                                    recent.id == recipe.id
                                                }),
                                                onTap: {
                                                    selectRecipe(recipe)
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            if let selectedRecipe {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label("Selected recipe", systemImage: "checkmark.circle.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.wickedGreen)

                                        Spacer()

                                        if selectedRecipe.isFavorite {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(Color.glindaPink)
                                        }
                                    }

                                    Text(selectedRecipe.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 12) {
                                        MealRecipeMetaBadge(
                                            title: AppOptionCatalog.localizedTitle(
                                                for: selectedRecipe.category,
                                                in: AppOptionCatalog.recipeCategories
                                            ),
                                            systemImage: "square.grid.2x2.fill"
                                        )
                                        MealRecipeMetaBadge(
                                            title: "\(selectedRecipe.preparationTimeMinutes) min",
                                            systemImage: "clock.fill"
                                        )
                                        MealRecipeMetaBadge(
                                            title: "\(selectedRecipe.servings) serv.",
                                            systemImage: "person.2.fill"
                                        )
                                    }

                                    Stepper(value: $plannedServings, in: 1...20) {
                                        Text("Servings eaten: **\(plannedServings)**")
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Text("This recipe makes \(selectedRecipe.servings) servings in total. Choose how many servings were eaten for this meal.")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.wickedGreen.opacity(0.35), lineWidth: 1)
                                )
                            } else {
                                Text("Tap a recipe card to select it.")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                Button("Save Meal") { saveMeal() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.wickedGreen)
                    .disabled(selectedRecipe == nil)
                    .padding()
            }
            .wickedReadableWidth(760)
        }
        .onAppear {
            let normalized = AppOptionCatalog.canonicalValue(
                for: defaultMealType,
                in: AppOptionCatalog.mealTypes
            )
            selectedMealType = AppOptionCatalog.contains(normalized, in: AppOptionCatalog.mealTypes)
                ? normalized
                : "breakfast"
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }
    
    private func saveMeal() {
        guard let recipe = selectedRecipe, let userId = authManager.user?.uid else {
            errorMessage = AppLocalization.key("An unknown error occurred.")
            return
        }
        
        let newEntry = MealPlanEntry(
            userId: userId,
            date: selectedDate,
            mealType: selectedMealType,
            recipeId: recipe.id ?? "",
            recipeName: recipe.name,
            plannedServings: plannedServings
        )
        
        Task {
            do {
                try await mealPlannerManager.addMealPlanEntry(entry: newEntry)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = AppLocalization.key("An unknown error occurred.")
                }
            }
        }
    }

    private func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        plannedServings = 1
        errorMessage = nil
    }

    private func isSelected(_ recipe: Recipe) -> Bool {
        guard let selectedRecipe else { return false }

        if let recipeID = recipe.id, let selectedID = selectedRecipe.id {
            return recipeID == selectedID
        }

        return recipe.name == selectedRecipe.name && recipe.dateAdded == selectedRecipe.dateAdded
    }

    private func matchesSearch(_ recipe: Recipe) -> Bool {
        let searchableText = [
            recipe.name,
            recipe.category,
            AppOptionCatalog.displayName(
                for: recipe.category,
                in: AppOptionCatalog.recipeCategories,
                locale: locale
            ),
            recipe.ingredients.map(\.name).joined(separator: " ")
        ]
            .map(normalized)
            .joined(separator: " ")

        return searchableText.contains(normalizedSearchText)
    }

    private func recentRecipeIDs(for mealType: String?) -> [String] {
        let relevantEntries = mealPlannerManager.allMealPlanEntries
            .filter { entry in
                mealType == nil || entry.canonicalMealType == mealType
            }
            .sorted { lhs, rhs in
                lhs.date > rhs.date
            }

        var seen = Set<String>()
        var result: [String] = []

        for entry in relevantEntries {
            guard !entry.recipeId.isEmpty else { continue }
            guard seen.insert(entry.recipeId).inserted else { continue }
            result.append(entry.recipeId)
        }

        return result
    }

    private func sortRecipes(_ recipes: [Recipe]) -> [Recipe] {
        let overallRecentRanks = Dictionary(
            uniqueKeysWithValues: overallRecentRecipeIDs.enumerated().map { index, recipeID in
                (recipeID, index)
            }
        )

        return recipes.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }

            let lhsRecentRank = lhs.id.flatMap { overallRecentRanks[$0] } ?? Int.max
            let rhsRecentRank = rhs.id.flatMap { overallRecentRanks[$0] } ?? Int.max
            if lhsRecentRank != rhsRecentRank {
                return lhsRecentRank < rhsRecentRank
            }

            if lhs.dateAdded != rhs.dateAdded {
                return lhs.dateAdded > rhs.dateAdded
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct MealRecipeSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.glindaPink)

            NativeTextField(
                text: $searchText,
                placeholder: "Search by recipe, category, or ingredient",
                autocorrectionType: .no,
                autocapitalizationType: .sentences,
                returnKeyType: .search
            )

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct MealRecipeFilterChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.darkBackground : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.wickedGreen : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealRecipeQuickSection: View {
    let title: Text
    let recipes: [Recipe]
    let selectedRecipe: Recipe?
    let onSelect: (Recipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.glindaPink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recipes) { recipe in
                        MealRecipeQuickPickCard(
                            recipe: recipe,
                            isSelected: isSelected(recipe),
                            onTap: { onSelect(recipe) }
                        )
                    }
                }
            }
        }
    }

    private func isSelected(_ recipe: Recipe) -> Bool {
        guard let selectedRecipe else { return false }

        if let recipeID = recipe.id, let selectedID = selectedRecipe.id {
            return recipeID == selectedID
        }

        return recipe.name == selectedRecipe.name && recipe.dateAdded == selectedRecipe.dateAdded
    }
}

private struct MealRecipeQuickPickCard: View {
    let recipe: Recipe
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: recipe.isFavorite ? "star.fill" : "fork.knife.circle.fill")
                        .foregroundStyle(recipe.isFavorite ? Color.glindaPink : Color.wickedGreen)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.wickedGreen)
                    }
                }

                Text(recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(AppOptionCatalog.localizedTitle(for: recipe.category, in: AppOptionCatalog.recipeCategories))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(width: 180, alignment: .leading)
            .background(Color.white.opacity(isSelected ? 0.14 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.wickedGreen.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealRecipeSelectionRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: recipe.isFavorite ? "star.fill" : "fork.knife")
                        .foregroundStyle(recipe.isFavorite ? Color.glindaPink : Color.wickedGreen)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(recipe.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if isRecommended {
                            Text("Recent")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.darkBackground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.glindaPink)
                                .clipShape(Capsule())
                        }
                    }

                    Text(AppOptionCatalog.localizedTitle(for: recipe.category, in: AppOptionCatalog.recipeCategories))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        MealRecipeMetaBadge(title: "\(recipe.preparationTimeMinutes) min", systemImage: "clock")
                        MealRecipeMetaBadge(title: "\(recipe.servings) serv.", systemImage: "person.2")
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.wickedGreen : Color.white.opacity(0.25))
            }
            .padding(14)
            .background(Color.white.opacity(isSelected ? 0.14 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.wickedGreen.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealRecipeMetaBadge: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
    }
}
