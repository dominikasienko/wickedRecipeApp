//
//  ShoppingListView.swift
//

import SwiftUI

// MARK: - Widok główny

struct ShoppingListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(ShoppingListManager.self) private var shoppingListManager
    
    @State private var startDate: Date = Date().startOfDay
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date().startOfDay) ?? Date()
    
    @State private var isGeneratorExpanded: Bool = true
    @State private var isShowingManualAddSheet: Bool = false
    
    private var itemsToBuy: [ShoppingListItem] {
        shoppingListManager.shoppingList.filter { !$0.isCompleted }.sorted(by: { $0.name < $1.name })
    }
    private var itemsPurchased: [ShoppingListItem] {
        shoppingListManager.shoppingList.filter { $0.isCompleted }.sorted(by: { $0.name < $1.name })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.darkBackground.ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.glindaPink.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .position(x: 350, y: 100)
                    .blur(radius: 100)
                    .ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.wickedGreen.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .position(x: 50, y: 700)
                    .blur(radius: 80)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        
                        PlanningPeriodDisplay(manager: shoppingListManager)
                            .padding(.horizontal)

                        DisclosureGroup(isExpanded: $isGeneratorExpanded) {
                            VStack(spacing: 15) {
                                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                                DatePicker("End date", selection: $endDate, displayedComponents: .date)
                                    .onChange(of: endDate) {
                                        if endDate < startDate {
                                            startDate = endDate
                                        }
                                    }
                                    .onChange(of: startDate) {
                                        if startDate > endDate {
                                            endDate = startDate
                                        }
                                    }
                                
                                Button(action: generateShoppingList) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.down.doc.fill")
                                        Text("Generate Shopping List")
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.wickedGreen)
                                .padding(.top, 5)
                            }
                            .padding()
                            .tint(.glindaPink)
                            
                        } label: {
                            Text("Generate from Meal Plan")
                                .font(.headline).bold()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        

                        if shoppingListManager.shoppingList.isEmpty {
                            ContentUnavailableView(
                                "List is empty",
                                systemImage: "list.clipboard",
                                description: Text("Generate a list from your meal plan or tap the '+' button to add items manually.")
                            )
                            .foregroundStyle(.gray)
                            .padding(.top, 50)
                        } else {
                            if !itemsToBuy.isEmpty {
                                ShoppingListSection(
                                    title: "To Buy",
                                    items: itemsToBuy,
                                    onToggle: shoppingListManager.toggleCompletion,
                                    onDelete: shoppingListManager.deleteItem
                                )
                            }
                            if !itemsPurchased.isEmpty {
                                ShoppingListSection(
                                    title: "Purchased",
                                    items: itemsPurchased,
                                    onToggle: shoppingListManager.toggleCompletion,
                                    onDelete: shoppingListManager.deleteItem
                                )
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
                
                Button {
                    isShowingManualAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .frame(width: 60, height: 60)
                        .background(Color.glindaPink)
                        .foregroundColor(.black)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding()
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $isShowingManualAddSheet) {
                ManualAddItemSheet { name in
                    addManualItem(name: name)
                }
                .presentationDetents([.height(200)])
                .preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                if endDate < startDate {
                    endDate = startDate
                }
            }
        }
    }
    
// MARK: - Logika
    
    func generateShoppingList() {
        let currentList = shoppingListManager.shoppingList
        
        let completionMap: [String: Bool] = Dictionary(uniqueKeysWithValues: currentList.map { item in
            let key = "\(item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))-\(item.unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            return (key, item.isCompleted)
        })
        
        let manualItems = currentList.filter { $0.isManuallyAdded }
        
        let filteredEntries = mealPlannerManager.allMealPlanEntries.filter { entry in
            return entry.date.startOfDay >= startDate && entry.date.startOfDay <= endDate
        }
        
        guard !filteredEntries.isEmpty else {
            shoppingListManager.setList(manualItems, from: nil, to: nil)
            isGeneratorExpanded = false
            UIApplication.shared.endEditing()
            return
        }
        
        let allRecipes = recipeManager.userRecipes
        var generatedItems = ShoppingListManager.generateList(from: filteredEntries, allRecipes: allRecipes)
        
        generatedItems = generatedItems.map { item in
            var updatedItem = item
            let key = "\(item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))-\(item.unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            if let isCompleted = completionMap[key] {
                updatedItem.isCompleted = isCompleted
            }
            return updatedItem
        }
        
        let combinedItems = generatedItems + manualItems
        let finalAggregatedList = aggregate(items: combinedItems)
        
        shoppingListManager.setList(finalAggregatedList, from: startDate, to: endDate)
        
        isGeneratorExpanded = false
        UIApplication.shared.endEditing()
    }
    
    /// AGREGACJA SKŁADNIKÓW
    private func aggregate(items: [ShoppingListItem]) -> [ShoppingListItem] {
        var aggregatedDict = [String: ShoppingListItem]()
        
        for item in items {
            let nameKey = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let unitKey = item.unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(nameKey)-\(unitKey)"
            
            if var existingItem = aggregatedDict[key] {
                existingItem.quantity += item.quantity
                existingItem.isCompleted = existingItem.isCompleted || item.isCompleted
                existingItem.isManuallyAdded = existingItem.isManuallyAdded || item.isManuallyAdded
                
                if let newSources = item.recipeSources {
                    let existingSources = existingItem.recipeSources ?? []
                    let newUniqueSources = newSources.filter { !existingSources.contains($0) }
                    existingItem.recipeSources = existingSources + newUniqueSources
                }
                
                aggregatedDict[key] = existingItem
            } else {
                var cleanItem = item
                cleanItem.name = nameKey.capitalized
                cleanItem.unit = unitKey
                aggregatedDict[key] = cleanItem
            }
        }
        return Array(aggregatedDict.values)
    }

    /// Dodaje produkt wpisany ręcznie (wywołuje Menedżera)
    func addManualItem(name: String) {
        guard !name.isEmpty else { return }
        
        let newItem = ShoppingListItem(
            name: name,
            quantity: 1,
            unit: "piece",
            isCompleted: false,
            isManuallyAdded: true,
            recipeSources: nil
        )
        
        let combinedList = shoppingListManager.shoppingList + [newItem]
        let finalAggregatedList = aggregate(items: combinedList)
        
        shoppingListManager.setList(finalAggregatedList,
                                    from: shoppingListManager.currentStartDate,
                                    to: shoppingListManager.currentEndDate)
    }
}


// MARK: Wyświetlanie Zakresu Dat

struct PlanningPeriodDisplay: View {
    @Bindable var manager: ShoppingListManager
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        Group {
            if let start = manager.currentStartDate, let end = manager.currentEndDate {
                HStack(spacing: 4) {
                    Text("Generated for:")
                        .font(.caption)
                    Text("\(start, formatter: Self.dateFormatter) - \(end, formatter: Self.dateFormatter)")
                        .font(.callout).bold()
                }
                .foregroundStyle(.gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            } else if !manager.shoppingList.isEmpty {
                Text("List contains manually added items.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Widoki Pomocnicze 

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ShoppingListSection: View {
    let title: String
    let items: [ShoppingListItem]
    let onToggle: (ShoppingListItem) -> Void
    let onDelete: (ShoppingListItem) -> Void
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        ShoppingListRow(
                            item: item,
                            onToggle: { onToggle(item) },
                            onDelete: { onDelete(item) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ShoppingListRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color.glindaPink : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundStyle(item.isCompleted ? .gray : .white)
                    .font(.headline)
                
                if let sources = item.recipeSources, !sources.isEmpty {
                    Text("from: \(sources.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .strikethrough(item.isCompleted, color: .gray)
                }
                else if item.isManuallyAdded {
                    Text("Manually added")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .strikethrough(item.isCompleted, color: .gray)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
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

struct ManualAddItemSheet: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (String) -> Void
    
    @State private var newItemName: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Add manual item")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                TextField("e.g., Paper towels", text: $newItemName)
                    .focused($isFocused)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                
                Button("Add to list") {
                    onSave(newItemName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.glindaPink)
                .frame(maxWidth: .infinity)
                .disabled(newItemName.isEmpty)
            }
            .padding()
        }
        .onAppear {
            isFocused = true
        }
    }
}
