import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(ShoppingListManager.self) private var shoppingListManager
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2

    @State private var selectedPeriod: ShoppingListPeriod = .week
    @State private var periodAnchor = Calendar.current.startOfDay(for: Date())
    @State private var isGeneratorExpanded = true
    @State private var isShowingAddSheet = false
    @State private var editingItem: ShoppingListItem?

    private var dateCalendar: Calendar {
        MealPlanningCalendar.configured(locale: locale, firstWeekday: weekStartDay)
    }

    private var selectedRange: MealPlanningDateRange? {
        MealPlanningCalendar.dateRange(for: selectedPeriod, containing: periodAnchor, calendar: dateCalendar)
    }

    private var visibleItems: [ShoppingListItem] {
        shoppingListManager.shoppingList
            .filter { !$0.isExcludedFromGeneration }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var itemsToBuy: [ShoppingListItem] { visibleItems.filter { !$0.isCompleted } }
    private var itemsPurchased: [ShoppingListItem] { visibleItems.filter(\.isCompleted) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.darkBackground.ignoresSafeArea()
                WickedAmbientGlowLayer(pinkOpacity: 0.3, greenOpacity: 0.3, greenDiameter: 200)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        PlanningPeriodDisplay(manager: shoppingListManager)

                        DisclosureGroup(isExpanded: $isGeneratorExpanded) {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("Planning period", selection: $selectedPeriod) {
                                    ForEach(ShoppingListPeriod.allCases) { period in
                                        Text(LocalizedStringKey(period.title)).tag(period)
                                    }
                                }
                                .pickerStyle(.segmented)

                                DatePicker("Date in period", selection: $periodAnchor, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(.wickedGreen)

                                if let selectedRange {
                                    HStack {
                                        Text(selectedRange.startDate, format: .dateTime.month(.abbreviated).day().year())
                                        Text(verbatim: "–")
                                        Text(selectedRange.lastDay(calendar: dateCalendar), format: .dateTime.month(.abbreviated).day().year())
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                                }

                                Button(action: generateShoppingList) {
                                    Label("Generate or refresh list", systemImage: "arrow.triangle.2.circlepath")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.wickedGreen)
                                .disabled(selectedRange == nil)
                                .accessibilityIdentifier("shoppingList.generate")
                            }
                            .padding(.top, 12)
                        } label: {
                            Label("Generate from meal plan", systemImage: "calendar.badge.plus")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if visibleItems.isEmpty {
                            ContentUnavailableView(
                                "List is empty",
                                systemImage: "list.clipboard",
                                description: Text("Generate a list for a day, week, or month, or add products yourself.")
                            )
                            .foregroundStyle(.gray)
                            .padding(.top, 24)
                        } else {
                            ShoppingListSection(
                                title: "To buy",
                                items: itemsToBuy,
                                onToggle: shoppingListManager.toggleCompletion,
                                onEdit: { editingItem = $0 },
                                onDelete: shoppingListManager.deleteItem
                            )
                            ShoppingListSection(
                                title: "Purchased",
                                items: itemsPurchased,
                                onToggle: shoppingListManager.toggleCompletion,
                                onEdit: { editingItem = $0 },
                                onDelete: shoppingListManager.deleteItem
                            )
                        }

                        Text("Refreshing the same period keeps purchased items, your edits, removed generated ingredients, and custom products.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 90)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .wickedReadableWidth(920)
                }

                Button {
                    isShowingAddSheet = true
                } label: {
                    Label("Add product", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(Color.glindaPink, in: Capsule())
                        .foregroundStyle(.black)
                        .shadow(radius: 10)
                }
                .padding()
                .accessibilityIdentifier("shoppingList.addItem")
            }
            .navigationTitle("Shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                ShoppingListItemEditorSheet(item: nil) { item in
                    shoppingListManager.addItem(item)
                }
            }
            .sheet(item: $editingItem) { item in
                ShoppingListItemEditorSheet(item: item) { updated in
                    shoppingListManager.updateItem(updated)
                }
            }
            .onAppear {
                if let start = shoppingListManager.currentStartDate {
                    periodAnchor = start
                    if let end = shoppingListManager.currentEndDate {
                        let length = dateCalendar.dateComponents([.day], from: start, to: end).day
                        if length == 0 {
                            selectedPeriod = .day
                        } else if length == 6 {
                            selectedPeriod = .week
                        } else if dateCalendar.isDate(start, equalTo: end, toGranularity: .month),
                                  dateCalendar.component(.day, from: start) == 1 {
                            selectedPeriod = .month
                        }
                    }
                }
            }
        }
    }

    private func generateShoppingList() {
        guard let selectedRange else { return }
        shoppingListManager.regenerate(
            from: mealPlannerManager.allMealPlanEntries,
            recipes: recipeManager.userRecipes,
            within: selectedRange,
            calendar: dateCalendar
        )
        isGeneratorExpanded = false
        UIApplication.shared.endEditing()
    }
}

struct PlanningPeriodDisplay: View {
    @Bindable var manager: ShoppingListManager

    var body: some View {
        Group {
            if let start = manager.currentStartDate, let end = manager.currentEndDate {
                HStack(spacing: 6) {
                    Text("Generated for")
                        .font(.caption)
                    Text(start, format: .dateTime.month(.abbreviated).day().year())
                    Text(verbatim: "–")
                    Text(end, format: .dateTime.month(.abbreviated).day().year())
                }
                .font(.callout.bold())
                .foregroundStyle(.white.opacity(0.75))
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: Capsule())
            } else if manager.shoppingList.contains(where: { $0.isManuallyAdded && !$0.isExcludedFromGeneration }) {
                Text("List contains custom products")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

struct ShoppingListSection: View {
    let title: LocalizedStringKey
    let items: [ShoppingListItem]
    let onToggle: (ShoppingListItem) -> Void
    let onEdit: (ShoppingListItem) -> Void
    let onDelete: (ShoppingListItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)

                LazyVStack(spacing: 9) {
                    ForEach(items) { item in
                        ShoppingListRow(
                            item: item,
                            onToggle: { onToggle(item) },
                            onEdit: { onEdit(item) },
                            onDelete: { onDelete(item) }
                        )
                    }
                }
            }
        }
    }
}

struct ShoppingListRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color.glindaPink : .gray)
                    .frame(width: 36, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.isCompleted ? "Mark as not purchased" : "Mark as purchased"))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundStyle(item.isCompleted ? .gray : .white)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let amount = item.amountDescription {
                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                if let note = item.quantityNote, !note.isEmpty {
                    Text(LocalizedStringKey(note))
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.85))
                }
                if let sources = item.recipeSources, !sources.isEmpty {
                    Text("From: \(sources.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                } else if item.isManuallyAdded {
                    Text("Custom product")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(Color.wickedGreen)
                    .frame(width: 36, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Edit shopping item"))

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 36, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove shopping item"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .alert(AppLocalization.key("Remove this item?"), isPresented: $showingDeleteConfirmation) {
            Button(AppLocalization.key("Remove"), role: .destructive, action: onDelete)
            Button(AppLocalization.key("Cancel"), role: .cancel) { }
        } message: {
            Text(AppLocalization.key(item.isManuallyAdded
                                     ? "This removes the custom product from your list."
                                     : "This hides the generated ingredient and keeps it removed when you refresh this period."))
        }
    }
}

struct ShoppingListItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ShoppingListItem?
    let onSave: (ShoppingListItem) -> Void

    @State private var name: String
    @State private var quantityText: String
    @State private var unit: String
    @State private var validationError: LocalizedStringKey?

    init(item: ShoppingListItem?, onSave: @escaping (ShoppingListItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _quantityText = State(initialValue: item.flatMap { $0.quantity > 0 ? String($0.quantity) : nil } ?? "")
        _unit = State(initialValue: item?.unit ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                Form {
                    Section("Product") {
                        TextField("Product name", text: $name)
                            .accessibilityIdentifier("shoppingList.itemName")
                        TextField("Quantity (optional)", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("shoppingList.itemQuantity")
                        TextField("Unit (optional)", text: $unit)
                            .accessibilityIdentifier("shoppingList.itemUnit")
                    }
                    Section {
                        Text("Edits to recipe ingredients are kept when you refresh the same planning period.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(item == nil ? "Add product" : "Edit product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(AppLocalization.key("Check the shopping item"), isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button(AppLocalization.key("OK"), role: .cancel) { validationError = nil }
            } message: {
                Text(validationError ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmedName = ShoppingListGenerator.cleanedName(name)
        let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity: Double
        if trimmedQuantity.isEmpty {
            quantity = 0
        } else {
            let normalized = trimmedQuantity.replacingOccurrences(of: ",", with: ".")
            guard let parsed = Double(normalized), parsed.isFinite, parsed >= 0 else {
                validationError = AppLocalization.key("Enter a valid non-negative quantity.")
                return
            }
            quantity = parsed
        }

        var saved = item ?? ShoppingListItem(
            name: trimmedName,
            quantity: 0,
            unit: "",
            isManuallyAdded: true
        )
        saved.name = trimmedName
        saved.quantity = quantity
        saved.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(saved)
        dismiss()
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
