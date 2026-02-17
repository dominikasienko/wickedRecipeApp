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
    @Environment(AuthManager.self) private var authManager
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.wickedGreen.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .position(x: 50, y: 100)
                    .blur(radius: 100)
                    .ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.glindaPink.opacity(0.2))
                    .frame(width: 250, height: 250)
                    .position(x: 300, y: 700)
                    .blur(radius: 80)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    
                    VStack {
                        MonthHeader(currentMonthDate: $currentMonthDate)
                        
                        CalendarGrid(
                            currentMonthDate: currentMonthDate,
                            selectedDate: $selectedDate,
                            entries: mealPlannerManager.allMealPlanEntries
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    DailyMealsSection(
                        selectedDate: selectedDate,
                        entries: entriesForDay
                    )
                    
                    Button("Add Meal") { isShowingAddSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.wickedGreen) // STYL WICKED
                        .padding(.bottom, 10)
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
                .preferredColorScheme(.dark)
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
            .preferredColorScheme(.dark)
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
            }
            Text(currentMonthDate, format: .dateTime.month(.wide).year())
                .font(.title2).bold()
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
            }
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
    let currentMonthDate: Date
    @Binding var selectedDate: Date
    let entries: [MealPlanEntry]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var days: [Date?] {
        let calendar = Calendar.current
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
            let symbols = Calendar.current.veryShortWeekdaySymbols
            HStack {
                ForEach(symbols.indices, id: \.self) { index in
                    Text(symbols[index])
                        .font(.caption).bold()
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.bottom, 5)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        DayCell(
                            date: date,
                            isSelected: date.isSameDay(as: selectedDate),
                            hasMeal: entries.contains(where: { $0.date.isSameDay(as: date) }),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonthDate, toGranularity: .month)
                        )
                        .onTapGesture { selectedDate = date }
                    } else { Color.clear }
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

struct DailyMealsSection: View {
    let selectedDate: Date
    let entries: [MealPlanEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Meals for \(selectedDate, style: .date)")
                .font(.title2).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
            
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No meals planned", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("Tap 'Add Meal' to schedule a recipe for this day.")
                }
                .foregroundStyle(.gray)
                .frame(maxHeight: .infinity)
                
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(entries) { entry in
                            MealCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: KARTA POSIŁKU
struct MealCard: View {
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    let entry: MealPlanEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mealType)
                    .font(.caption.bold())
                    .foregroundStyle(Color.glindaPink)
                
                Text(entry.recipeName)
                    .font(.headline)
                    .foregroundStyle(.white)
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

struct AddMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(AuthManager.self) private var authManager
    
    let selectedDate: Date
    let availableRecipes: [Recipe]
    
    @State private var selectedRecipe: Recipe?
    @State private var selectedMealType: String = Constants.mealTypes.first ?? "Breakfast"
    @State private var errorMessage: String?
    
    @State private var plannedServings: Int = 1
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.3))
                .frame(width: 200, height: 200)
                .position(x: 50, y: 100)
                .blur(radius: 80)
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
                                ForEach(Constants.mealTypes, id: \.self) { meal in
                                    Text(meal).tag(meal)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(.wickedGreen)
                            
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        
                        VStack(spacing: 15) {
                            Picker("Select recipe", selection: $selectedRecipe) {
                                Text("No choice").tag(nil as Recipe?)
                                ForEach(availableRecipes) { recipe in
                                    Text(recipe.name).tag(recipe as Recipe?)
                                }
                            }
                            .tint(.white)
                            
                            if let selectedRecipe {
                                Stepper(value: $plannedServings, in: 1...20) {
                                    Text("Number of servings: **\(plannedServings)**")
                                }
                                
                                Text("The original recipe makes \(selectedRecipe.servings) servings.")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        
                        if let errorMessage = errorMessage {
                            Text("Error: \(errorMessage)")
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
        }
        .onChange(of: selectedRecipe) { _, newRecipe in
            plannedServings = newRecipe?.servings ?? 1
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
            errorMessage = "Select a recipe and ensure you are logged in."
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
                    errorMessage = "Unable to save meal: \(error.localizedDescription)"
                }
            }
        }
    }
}
