//
//  MealPlannerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import SwiftUI
import FirebaseAuth

private enum MealPlannerSheetRoute: Identifiable {
    case add(id: UUID, date: Date, mealType: String?)
    case edit(MealPlanEntry)
    case shoppingList

    var id: String {
        switch self {
        case let .add(id, _, _): return "add-\(id.uuidString)"
        case let .edit(entry): return "edit-\(entry.id ?? entry.recipeId)"
        case .shoppingList: return "shopping-list"
        }
    }
}

struct MealPlannerView: View {
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2
    
    @State private var calendarSelection = MealPlannerCalendarSelection(selectedDate: Date().startOfDay)
    @State private var activeSheet: MealPlannerSheetRoute?

    private var selectedDate: Date { calendarSelection.selectedDate }
    private var selectedViewMode: MealPlannerCalendarViewMode { calendarSelection.viewMode }

    private var calendarAnimation: Animation? {
        let duration = MealPlannerCalendarMotion.duration(reduceMotion: reduceMotion)
        return duration == 0 ? nil : .easeInOut(duration: duration)
    }

    private var calendarViewTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { calendarSelection.selectedDate },
            set: { date in
                withAnimation(calendarAnimation) {
                    calendarSelection.selectDate(date, calendar: dateCalendar)
                }
            }
        )
    }

    private var selectedViewModeBinding: Binding<MealPlannerCalendarViewMode> {
        Binding(
            get: { calendarSelection.viewMode },
            set: { mode in
                withAnimation(calendarAnimation) {
                    calendarSelection.selectViewMode(mode)
                }
            }
        )
    }
    
    var availableRecipes: [Recipe] {
        recipeManager.userRecipes
    }
    
    var entriesForDay: [MealPlanEntry] {
        mealPlannerManager.entriesForDay(selectedDate)
    }

    private var dateCalendar: Calendar {
        MealPlanningCalendar.configured(locale: locale, firstWeekday: weekStartDay)
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
                    VStack(spacing: 12) {
                        Picker("Calendar view", selection: selectedViewModeBinding) {
                            ForEach(MealPlannerCalendarViewMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.title)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.wickedGreen)
                        .padding(.horizontal)
                        .accessibilityIdentifier("mealPlanner.viewMode")

                        calendarContent(width: geometry.size.width)
                            .animation(calendarAnimation, value: selectedViewMode)
                            .animation(calendarAnimation, value: selectedDate)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
            }
            .navigationTitle("Meal Plan")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.darkBackground.opacity(0.5), for: .navigationBar)
            .sheet(item: $activeSheet) { route in
                switch route {
                case let .add(_, date, mealType):
                    AddMealSheet(
                        selectedDate: date,
                        availableRecipes: availableRecipes,
                        initialMealType: mealType
                    )
                case let .edit(entry):
                    AddMealSheet(
                        selectedDate: entry.date,
                        availableRecipes: availableRecipes,
                        editingEntry: entry
                    )
                case .shoppingList:
                    ShoppingListView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .shoppingList
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

    @ViewBuilder
    private func calendarContent(width: CGFloat) -> some View {
        switch selectedViewMode {
        case .day:
            ScrollView {
                VStack(spacing: 12) {
                    periodNavigation
                    DailyMealsSection(
                        selectedDate: selectedDate,
                        entries: entriesForDay,
                        nutritionSummary: nutritionSummary,
                        recipesById: recipesById,
                        onAddMeal: { showAddMeal(for: $0) },
                        onEditMeal: { activeSheet = .edit($0) }
                    )
                }
                .padding(.bottom, 20)
                .wickedReadableWidth(820)
            }
            .transition(calendarViewTransition)
        case .week:
            weeklyContent(width: width)
                .transition(calendarViewTransition)
        case .month:
            monthContent(width: width)
                .transition(calendarViewTransition)
        }
    }

    private var periodNavigation: some View {
        HStack(spacing: 10) {
            Button { moveSelection(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Previous period"))

            VStack(spacing: 2) {
                Text(periodTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button("Today") {
                    withAnimation(calendarAnimation) {
                        calendarSelection.returnToToday(Date(), calendar: dateCalendar)
                    }
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wickedGreen)
            }
            .frame(maxWidth: .infinity)
            .simultaneousGesture(periodSwipeGesture)

            Button { moveSelection(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Next period"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
    }

    private var periodTitle: String {
        switch selectedViewMode {
        case .day:
            return selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year().locale(locale))
        case .week:
            guard let range = MealPlanningCalendar.dateRange(for: .week, containing: selectedDate, calendar: dateCalendar) else {
                return selectedDate.formatted(date: .abbreviated, time: .omitted)
            }
            let end = range.lastDay(calendar: dateCalendar)
            return "\(range.startDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))) – \(end.formatted(.dateTime.month(.abbreviated).day().year().locale(locale)))"
        case .month:
            return selectedDate.formatted(.dateTime.month(.wide).year().locale(locale))
        }
    }

    private func monthContent(width: CGFloat) -> some View {
        let calendarCard = VStack(spacing: 12) {
            periodNavigation
            CalendarGrid(
                currentMonthDate: selectedDate.startOfMonth,
                selectedDate: selectedDateBinding,
                entries: mealPlannerManager.allMealPlanEntries,
                firstWeekday: weekStartDay
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)

        return ScrollView {
            Group {
                if width >= 720 {
                    HStack(alignment: .top, spacing: 18) {
                        calendarCard.frame(maxWidth: 380)
                        dailyDetails
                    }
                } else {
                    VStack(spacing: 10) {
                        calendarCard
                        dailyDetails
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .wickedReadableWidth(width >= 720 ? 1_280 : 820)
        }
    }

    private var dailyDetails: some View {
        DailyMealsSection(
            selectedDate: selectedDate,
            entries: entriesForDay,
            nutritionSummary: nutritionSummary,
            recipesById: recipesById,
            onAddMeal: { showAddMeal(for: $0) },
            onEditMeal: { activeSheet = .edit($0) }
        )
    }

    private func weeklyContent(width: CGFloat) -> some View {
        guard let range = MealPlanningCalendar.dateRange(for: .week, containing: selectedDate, calendar: dateCalendar) else {
            return AnyView(ContentUnavailableView("Calendar unavailable", systemImage: "calendar.badge.exclamationmark"))
        }
        let days = MealPlanningCalendar.dates(in: range, calendar: dateCalendar)
        let entriesByDay = Dictionary(grouping: mealPlannerManager.allMealPlanEntries) {
            dateCalendar.startOfDay(for: $0.date)
        }
        let columns = Array(repeating: GridItem(.flexible(), alignment: .top), count: width >= 720 ? 2 : 1)

        return AnyView(VStack(spacing: 8) {
            periodNavigation
            ScrollView {
                LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        WeeklyDayCard(
                            date: day,
                            calendar: dateCalendar,
                            isSelected: dateCalendar.isDate(day, inSameDayAs: selectedDate),
                            entries: entriesByDay[dateCalendar.startOfDay(for: day)] ?? [],
                            recipesById: recipesById,
                            onAddMeal: { showAddMeal(for: $0, on: day) },
                            onEditMeal: { activeSheet = .edit($0) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .wickedReadableWidth(width >= 720 ? 1_280 : 820)
            }
        })
    }

    private func showAddMeal(for mealType: String? = nil, on date: Date? = nil) {
        let targetDate = date ?? selectedDate
        selectedDateBinding.wrappedValue = targetDate
        activeSheet = .add(id: UUID(), date: targetDate, mealType: mealType)
    }

    private func moveSelection(by amount: Int) {
        withAnimation(calendarAnimation) {
            calendarSelection.navigate(by: amount, calendar: dateCalendar)
        }
    }

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 32)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > 64,
                      abs(horizontal) > abs(value.translation.height) * 1.25 else { return }
                moveSelection(by: horizontal < 0 ? 1 : -1)
            }
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
    let recipesById: [String: Recipe]
    let onAddMeal: (String?) -> Void
    let onEditMeal: (MealPlanEntry) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Meals for \(selectedDate, style: .date)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    onAddMeal(nil)
                } label: {
                    Label("Add meal", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.wickedGreen)
            }
            .padding(.top, 8)

            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No meals planned", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("Choose a meal category below to plan a recipe for this day.")
                }
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            ForEach(AppOptionCatalog.mealTypes) { meal in
                let categoryEntries = entries.filter { $0.canonicalMealType == meal.id }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(meal.title)
                            .font(.headline)
                            .foregroundStyle(Color.glindaPink)
                        Spacer()
                        Button {
                            onAddMeal(meal.id)
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.wickedGreen)
                        .accessibilityLabel(Text("Add planned meal"))
                    }

                    if categoryEntries.isEmpty {
                        Text("No recipe planned")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.vertical, 3)
                    } else {
                        ForEach(categoryEntries) { entry in
                            MealCard(entry: entry, recipe: recipesById[entry.recipeId]) {
                                onEditMeal(entry)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
            }

            DailyNutritionSummaryCard(summary: nutritionSummary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}

private struct WeeklyDayCard: View {
    let date: Date
    let calendar: Calendar
    let isSelected: Bool
    let entries: [MealPlanEntry]
    let recipesById: [String: Recipe]
    let onAddMeal: (String?) -> Void
    let onEditMeal: (MealPlanEntry) -> Void

    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide).locale(calendar.locale ?? .current)))
                        .font(.headline)
                        .foregroundStyle(isToday ? Color.wickedGreen : .white)
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                if isToday {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.darkBackground)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.wickedGreen, in: Capsule())
                }
                Button {
                    onAddMeal(nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.wickedGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add meal"))
            }

            if entries.isEmpty {
                Text("No meals planned")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(AppOptionCatalog.mealTypes) { meal in
                    let mealEntries = entries.filter { $0.canonicalMealType == meal.id }
                    if !mealEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(meal.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.glindaPink)
                            ForEach(mealEntries) { entry in
                                MealCard(entry: entry, recipe: recipesById[entry.recipeId]) {
                                    onEditMeal(entry)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? Color.glindaPink : (isToday ? Color.wickedGreen.opacity(0.65) : Color.white.opacity(0.12)),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
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
    let recipe: Recipe?
    let onEdit: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    
    var body: some View {
        HStack(spacing: 8) {
            if let recipe {
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    recipeLabel
                }
                .buttonStyle(.plain)
            } else {
                recipeLabel
            }

            Spacer(minLength: 4)

            Text("\(entry.plannedServings) ×")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(Color.wickedGreen)
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Edit planned meal"))

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove planned meal"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert(AppLocalization.key("Remove this planned meal?"), isPresented: $showingDeleteConfirmation) {
            Button(AppLocalization.key("Remove"), role: .destructive) {
                Task { await deleteEntry() }
            }
            Button(AppLocalization.key("Cancel"), role: .cancel) { }
        } message: {
            Text(AppLocalization.key("This removes the meal from your plan. The recipe will not be deleted."))
        }
        .alert(AppLocalization.key("Could not update meal plan"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(AppLocalization.key("OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var recipeLabel: some View {
        HStack(spacing: 9) {
            if let imageURL = recipe?.imageURL, !imageURL.isEmpty {
                AsyncImageView(urlString: imageURL)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "fork.knife")
                    .frame(width: 42, height: 42)
                    .foregroundStyle(Color.wickedGreen)
                    .background(Color.wickedGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.localizedMealType)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.glindaPink)
                    .lineLimit(1)
                Text(entry.recipeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func deleteEntry() async {
        guard let entryID = entry.id else {
            errorMessage = MealPlanMutationError.missingEntryIdentifier.localizedDescription
            return
        }
        do {
            try await mealPlannerManager.deleteMealPlanEntry(entryId: entryID)
        } catch {
            errorMessage = error.localizedDescription
        }
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
    
    let availableRecipes: [Recipe]
    let initialMealType: String?
    let editingEntry: MealPlanEntry?
    
    @State private var selectedRecipe: Recipe?
    @State private var plannedDate: Date
    @State private var selectedMealType: String
    @State private var recipeSearchText: String = ""
    @State private var activeRecipeFilter: MealRecipeFilter = .all
    @State private var errorMessage: LocalizedStringKey?
    @State private var isSaving = false
    @State private var showingDuplicateConfirmation = false
    @State private var plannedServings: Int

    init(
        selectedDate: Date,
        availableRecipes: [Recipe],
        initialMealType: String? = nil,
        editingEntry: MealPlanEntry? = nil,
        initialRecipe: Recipe? = nil
    ) {
        self.availableRecipes = availableRecipes
        self.initialMealType = initialMealType
        self.editingEntry = editingEntry
        _plannedDate = State(initialValue: editingEntry?.date ?? selectedDate)
        _selectedMealType = State(initialValue: editingEntry?.mealType ?? initialMealType ?? "breakfast")
        _plannedServings = State(initialValue: editingEntry?.plannedServings ?? 1)
        _selectedRecipe = State(initialValue: initialRecipe ?? editingEntry.flatMap { entry in
            availableRecipes.first(where: { $0.id == entry.recipeId })
        })
    }

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
                Text(editingEntry == nil ? "Plan a meal" : "Edit planned meal")
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 15) {
                            DatePicker("Date", selection: $plannedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(.wickedGreen)
                            
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
                                        Text("Planned servings: **\(plannedServings)**")
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Text("This recipe makes \(selectedRecipe.servings) servings. Choose the number planned for this meal.")
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
                            } else if editingEntry != nil {
                                Text("The original recipe is no longer available. You can update this meal or choose a replacement recipe.")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
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
                
                Button(editingEntry == nil ? "Plan meal" : "Save changes") { saveMeal() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.wickedGreen)
                    .disabled((selectedRecipe == nil && editingEntry == nil) || isSaving)
                    .padding()
            }
            .wickedReadableWidth(760)
        }
        .onAppear {
            let candidate = editingEntry?.mealType ?? initialMealType ?? defaultMealType
            let normalized = AppOptionCatalog.canonicalValue(for: candidate.isEmpty ? defaultMealType : candidate, in: AppOptionCatalog.mealTypes)
            selectedMealType = AppOptionCatalog.contains(normalized, in: AppOptionCatalog.mealTypes) ? normalized : "breakfast"
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .alert(AppLocalization.key("This recipe is already planned for this meal"), isPresented: $showingDuplicateConfirmation) {
            Button(AppLocalization.key("Add another planned meal"), role: .destructive) {
                Task { await persistMeal() }
            }
            Button(AppLocalization.key("Cancel"), role: .cancel) { }
        } message: {
            Text(AppLocalization.key("You can plan the same recipe more than once. Add this as a separate meal?"))
        }
    }
    
    private func saveMeal() {
        guard (selectedRecipe?.id != nil || editingEntry != nil), authManager.user?.uid != nil else {
            errorMessage = AppLocalization.key("Choose a saved recipe and make sure you are signed in.")
            return
        }

        if editingEntry == nil, let recipe = selectedRecipe,
           mealPlannerManager.allMealPlanEntries.contains(where: { existing in
               existing.recipeId == recipe.id
                   && existing.canonicalMealType == selectedMealType
                   && Calendar.current.isDate(existing.date, inSameDayAs: plannedDate)
           }) {
            showingDuplicateConfirmation = true
            return
        }

        Task { await persistMeal() }
    }

    @MainActor
    private func persistMeal() async {
        guard let userID = authManager.user?.uid,
              let recipeID = selectedRecipe?.id ?? editingEntry?.recipeId,
              let recipeName = selectedRecipe?.name ?? editingEntry?.recipeName else {
            errorMessage = AppLocalization.key("Choose a saved recipe and make sure you are signed in.")
            return
        }
        isSaving = true
        defer { isSaving = false }

        do {
            if var entry = editingEntry {
                entry.date = Calendar.current.startOfDay(for: plannedDate)
                entry.mealType = selectedMealType
                entry.recipeId = recipeID
                entry.recipeName = recipeName
                entry.plannedServings = plannedServings
                try await mealPlannerManager.updateMealPlanEntry(entry: entry)
            } else {
                let entry = MealPlanEntry(
                    userId: userID,
                    date: plannedDate,
                    mealType: selectedMealType,
                    recipeId: recipeID,
                    recipeName: recipeName,
                    plannedServings: plannedServings
                )
                try await mealPlannerManager.addMealPlanEntry(entry: entry)
            }
            dismiss()
        } catch {
            errorMessage = AppLocalization.key("The meal plan could not be saved. Check your connection and try again.")
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
