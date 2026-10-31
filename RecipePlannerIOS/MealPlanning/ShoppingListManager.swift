import Foundation
import Observation

@Observable
class ShoppingListManager {
    private static let legacyStorageKey = "ShoppingListItems"
    private static let legacyDateKey = "ShoppingListDates"
    private static let migrationKey = "ShoppingListItemsUserScopeMigrationComplete"

    struct PlanningPeriod: Codable, Equatable {
        let startDate: Date?
        let endDate: Date?
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var activeUserID: String?
    @ObservationIgnored private var storageKey: String
    @ObservationIgnored private var dateKey: String

    var shoppingList: [ShoppingListItem] = []
    var currentStartDate: Date?
    var currentEndDate: Date?

    init(defaults: UserDefaults = .standard, userID: String? = nil) {
        self.defaults = defaults
        self.activeUserID = nil
        self.storageKey = Self.legacyStorageKey
        self.dateKey = Self.legacyDateKey

        if let userID {
            load(forUserID: userID)
        } else {
            loadStoredList()
        }
    }

    /// Loads a separate local list for the signed-in account. Legacy unscoped data is
    /// moved to the first account that opens the upgraded app, then removed from its
    /// old keys so another account cannot inherit it.
    func load(forUserID userID: String) {
        guard !userID.isEmpty, activeUserID != userID else { return }

        shoppingList = []
        currentStartDate = nil
        currentEndDate = nil
        activeUserID = userID
        storageKey = Self.itemsKey(for: userID)
        dateKey = Self.datesKey(for: userID)

        if defaults.data(forKey: storageKey) != nil || defaults.data(forKey: dateKey) != nil {
            loadStoredList()
            return
        }

        if !defaults.bool(forKey: Self.migrationKey) {
            if let legacyItems = defaults.data(forKey: Self.legacyStorageKey) {
                defaults.set(legacyItems, forKey: storageKey)
            }
            if let legacyDates = defaults.data(forKey: Self.legacyDateKey) {
                defaults.set(legacyDates, forKey: dateKey)
            }
            defaults.removeObject(forKey: Self.legacyStorageKey)
            defaults.removeObject(forKey: Self.legacyDateKey)
            defaults.set(true, forKey: Self.migrationKey)
            loadStoredList()
        }
    }

    private func loadStoredList() {
        if let savedData = defaults.data(forKey: storageKey) {
            do {
                shoppingList = try JSONDecoder().decode([ShoppingListItem].self, from: savedData)
            } catch {
                print("Failed to decode shopping list: \(error.localizedDescription)")
            }
        }

        if let savedDates = defaults.data(forKey: dateKey) {
            do {
                let period = try JSONDecoder().decode(PlanningPeriod.self, from: savedDates)
                currentStartDate = period.startDate
                currentEndDate = period.endDate
            } catch {
                print("Failed to decode shopping-list period: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(shoppingList), forKey: storageKey)
            let period = PlanningPeriod(startDate: currentStartDate, endDate: currentEndDate)
            defaults.set(try JSONEncoder().encode(period), forKey: dateKey)
        } catch {
            print("Failed to save shopping list: \(error.localizedDescription)")
        }
    }

    func setList(_ items: [ShoppingListItem], from startDate: Date? = nil, to endDate: Date? = nil) {
        shoppingList = items
        currentStartDate = startDate
        currentEndDate = endDate
        save()
    }

    func addItem(_ item: ShoppingListItem) {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !shoppingList.contains(where: { $0.id == item.id }) else { return }
        shoppingList.append(item)
        save()
    }

    func updateItem(_ item: ShoppingListItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.name = ShoppingListGenerator.cleanedName(updated.name)
        updated.isManuallyEdited = !updated.isManuallyAdded || updated.isManuallyEdited
        shoppingList[index] = updated
        save()
    }

    func toggleCompletion(_ item: ShoppingListItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }),
              !shoppingList[index].isExcludedFromGeneration else { return }
        shoppingList[index].isCompleted.toggle()
        save()
    }

    /// Removing a generated row leaves a hidden tombstone so refreshing the same
    /// period does not silently put it back. Custom rows are removed outright.
    func deleteItem(_ item: ShoppingListItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        if shoppingList[index].isManuallyAdded {
            shoppingList.remove(at: index)
        } else {
            shoppingList[index].isExcludedFromGeneration = true
            if shoppingList[index].ingredientIdentityKey == nil {
                shoppingList[index].ingredientIdentityKey = ShoppingListGenerator.normalizedIngredientIdentity(item.name)
            }
        }
        save()
    }

    func clearAll() {
        shoppingList = []
        currentStartDate = nil
        currentEndDate = nil
        save()
    }

    /// Clears only in-memory state when signing out; persisted account data remains
    /// available when that same account signs in again.
    func clearLocalData() {
        shoppingList = []
        currentStartDate = nil
        currentEndDate = nil
        activeUserID = nil
        storageKey = Self.legacyStorageKey
        dateKey = Self.legacyDateKey
    }

    func regenerate(
        from entries: [MealPlanEntry],
        recipes: [Recipe],
        within range: MealPlanningDateRange,
        calendar: Calendar = .current
    ) {
        let samePeriod = Self.samePeriod(
            currentStartDate,
            currentEndDate,
            range,
            calendar: calendar
        )
        let oldItems = shoppingList
        let manualItems = oldItems.filter { $0.isManuallyAdded && !$0.isExcludedFromGeneration }
        let tombstones = samePeriod ? oldItems.filter(\.isExcludedFromGeneration) : []
        let oldGenerated = samePeriod ? oldItems.filter { !$0.isManuallyAdded && !$0.isExcludedFromGeneration } : []

        let completedByGenerationKey = Dictionary(
            oldGenerated.compactMap { item -> (String, ShoppingListItem)? in
                guard let key = item.generationKey else { return nil }
                return (key, item)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let legacyByIdentity = Dictionary(
            oldGenerated.filter { $0.generationKey == nil && $0.ingredientIdentityKey == nil }.map {
                (ShoppingListGenerator.normalizedIngredientIdentity($0.name), $0)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let excludedGenerationKeys = Set(tombstones.compactMap(\.generationKey))
        let excludedLegacyIdentities = Set(tombstones.filter { $0.generationKey == nil }.compactMap { item in
            item.ingredientIdentityKey ?? ShoppingListGenerator.normalizedIngredientIdentity(item.name)
        })

        var generated = ShoppingListGenerator.generate(
            from: entries,
            recipes: recipes,
            within: range,
            calendar: calendar
        )
        var reusedPreviousIDs = Set<UUID>()
        generated = generated.compactMap { fresh in
            let identity = fresh.ingredientIdentityKey ?? ShoppingListGenerator.normalizedIngredientIdentity(fresh.name)
            guard !excludedGenerationKeys.contains(fresh.generationKey ?? ""),
                  !excludedLegacyIdentities.contains(identity) else { return nil }

            var item = fresh
            let previous = fresh.generationKey.flatMap { completedByGenerationKey[$0] }
                ?? legacyByIdentity[identity]
            if let previous, reusedPreviousIDs.insert(previous.id).inserted {
                item.id = previous.id
                item.isCompleted = previous.isCompleted
                if previous.isManuallyEdited {
                    item.name = previous.name
                    item.quantity = previous.quantity
                    item.unit = previous.unit
                    item.isManuallyEdited = true
                }
            }
            return item
        }

        shoppingList = generated + manualItems + tombstones
        currentStartDate = range.startDate
        currentEndDate = range.lastDay(calendar: calendar)
        save()
    }

    static func samePeriod(
        _ startDate: Date?,
        _ endDate: Date?,
        _ range: MealPlanningDateRange,
        calendar: Calendar
    ) -> Bool {
        guard let startDate, let endDate else { return false }
        return calendar.isDate(startDate, inSameDayAs: range.startDate)
            && calendar.isDate(endDate, inSameDayAs: range.lastDay(calendar: calendar))
    }

    static func normalizedIngredientKey(for rawName: String) -> String {
        ShoppingListGenerator.normalizedIngredientIdentity(rawName)
    }

    static func cleanedIngredientName(_ rawName: String) -> String {
        ShoppingListGenerator.cleanedName(rawName)
    }

    static func generateList(
        from entries: [MealPlanEntry],
        allRecipes: [Recipe],
        within range: MealPlanningDateRange? = nil,
        calendar: Calendar = .current
    ) -> [ShoppingListItem] {
        ShoppingListGenerator.generate(from: entries, recipes: allRecipes, within: range, calendar: calendar)
    }

    private static func itemsKey(for userID: String) -> String {
        "ShoppingListItems.\(userID)"
    }

    private static func datesKey(for userID: String) -> String {
        "ShoppingListDates.\(userID)"
    }
}
