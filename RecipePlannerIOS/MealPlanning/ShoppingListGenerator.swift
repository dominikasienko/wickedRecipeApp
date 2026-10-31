import Foundation

enum ShoppingListGenerator {
    private struct Accumulator {
        var item: ShoppingListItem
        var quantity: Decimal
    }

    static func normalizedIngredientIdentity(_ rawName: String) -> String {
        rawName
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[\\p{P}\\p{S}]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanedName(_ rawName: String) -> String {
        rawName
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func generate(
        from entries: [MealPlanEntry],
        recipes: [Recipe],
        within range: MealPlanningDateRange? = nil,
        calendar: Calendar = .current
    ) -> [ShoppingListItem] {
        var recipesByID: [String: Recipe] = [:]
        for recipe in recipes {
            guard let id = recipe.id else { continue }
            recipesByID[id] = recipe
        }

        var aggregated: [String: Accumulator] = [:]
        var unaggregated: [ShoppingListItem] = []

        for entry in entries {
            guard range?.contains(entry.date, calendar: calendar) ?? true,
                  entry.plannedServings > 0,
                  let recipe = recipesByID[entry.recipeId],
                  let recipeID = recipe.id else { continue }

            let hasServingBase = recipe.servings > 0
            let servingRatio = hasServingBase
                ? Decimal(entry.plannedServings) / Decimal(recipe.servings)
                : Decimal(1)
            let sectionIngredients = (recipe.sections ?? []).flatMap(\.ingredients)
            let ingredients = sectionIngredients.isEmpty ? recipe.ingredients : sectionIngredients
            for (index, ingredient) in ingredients.enumerated() {
                let name = cleanedName(ingredient.name)
                let identity = normalizedIngredientIdentity(name)
                guard !identity.isEmpty else { continue }

                let base = itemBase(
                    name: name,
                    identity: identity,
                    recipe: recipe,
                    recipeID: recipeID,
                    entry: entry,
                    quantityNote: hasServingBase ? nil : "Original recipe amount; serving count unavailable"
                )

                if !hasServingBase {
                    var item = base
                    item.quantity = ingredient.quantity.isFinite && ingredient.quantity > 0 ? ingredient.quantity : 0
                    item.unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.generationKey = sourceIngredientKey(entry: entry, recipeID: recipeID, index: index, calendar: calendar)
                    item.id = UUID()
                    unaggregated.append(item)
                    continue
                }

                guard ingredient.quantity.isFinite,
                      ingredient.quantity > 0,
                      let sourceQuantity = decimal(from: ingredient.quantity) else {
                    var item = base
                    item.unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Missing, descriptive, and invalid source quantities remain visible as
                    // separate rows; they are never converted into an invented amount.
                    item.generationKey = sourceIngredientKey(entry: entry, recipeID: recipeID, index: index, calendar: calendar)
                    item.id = UUID()
                    unaggregated.append(item)
                    continue
                }

                let scaledQuantity = sourceQuantity * servingRatio
                guard let unit = normalizedUnit(ingredient.unit),
                      let key = unit.key.map({ "\(identity)|\($0)" }) else {
                    var item = base
                    item.quantity = decimalToDouble(scaledQuantity)
                    item.unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.generationKey = sourceIngredientKey(entry: entry, recipeID: recipeID, index: index, calendar: calendar)
                    item.id = UUID()
                    unaggregated.append(item)
                    continue
                }

                let convertedQuantity = scaledQuantity * unit.multiplier
                if var existing = aggregated[key] {
                    existing.quantity += convertedQuantity
                    existing.item.recipeSources = appendingUnique(recipe.name, to: existing.item.recipeSources)
                    existing.item.sourceRecipeIDs = appendingUnique(recipeID, to: existing.item.sourceRecipeIDs)
                    if let entryID = entry.id {
                        existing.item.sourceMealEntryIDs = appendingUnique(entryID, to: existing.item.sourceMealEntryIDs)
                    }
                    aggregated[key] = existing
                } else {
                    var item = base
                    item.quantity = decimalToDouble(convertedQuantity)
                    item.unit = unit.canonicalUnit
                    item.generationKey = key
                    item.id = UUID()
                    aggregated[key] = Accumulator(item: item, quantity: convertedQuantity)
                }
            }
        }

        let combined = aggregated.values.map { accumulator -> ShoppingListItem in
            var item = accumulator.item
            item.quantity = decimalToDouble(accumulator.quantity)
            return item
        } + unaggregated

        return combined.sorted {
            let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            if $0.unit != $1.unit { return $0.unit.localizedCaseInsensitiveCompare($1.unit) == .orderedAscending }
            return ($0.generationKey ?? "") < ($1.generationKey ?? "")
        }
    }

    static func decimal(from value: Double) -> Decimal? {
        guard value.isFinite, value >= 0 else { return nil }
        return Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func itemBase(
        name: String,
        identity: String,
        recipe: Recipe,
        recipeID: String,
        entry: MealPlanEntry,
        quantityNote: String?
    ) -> ShoppingListItem {
        ShoppingListItem(
            name: name,
            quantity: 0,
            unit: "",
            isCompleted: false,
            isManuallyAdded: false,
            recipeSources: [recipe.name],
            sourceRecipeIDs: [recipeID],
            sourceMealEntryIDs: entry.id.map { [$0] },
            ingredientIdentityKey: identity,
            quantityNote: quantityNote
        )
    }

    private static func normalizedUnit(_ rawUnit: String) -> (canonicalUnit: String, multiplier: Decimal, key: String?)? {
        let normalized = rawUnit
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: ".", with: "")

        guard !normalized.isEmpty else { return nil }

        let mass: [String: String] = [
            "g": "1", "gram": "1", "grams": "1", "grama": "1", "gramy": "1", "gramow": "1",
            "kg": "1000", "kilogram": "1000", "kilograms": "1000", "kilogramy": "1000", "kilogramow": "1000",
            "mg": "0.001", "milligram": "0.001", "milligrams": "0.001"
        ]
        if let factor = mass[normalized], let decimalFactor = Decimal(string: factor) {
            return ("g", decimalFactor, "mass:g")
        }

        let volume: [String: String] = [
            "ml": "1", "milliliter": "1", "milliliters": "1", "millilitre": "1", "millilitres": "1",
            "l": "1000", "liter": "1000", "liters": "1000", "litre": "1000", "litres": "1000",
            "cl": "10"
        ]
        if let factor = volume[normalized], let decimalFactor = Decimal(string: factor) {
            return ("ml", decimalFactor, "volume:ml")
        }

        let counts: Set<String> = ["piece", "pieces", "pc", "pcs", "unit", "units", "szt", "sztuka", "sztuki", "sztuk"]
        if counts.contains(normalized) {
            return ("piece", 1, "count:piece")
        }

        // Unclassified units aggregate only with the same normalized unit. In particular,
        // tablespoons/cups are not converted to mass or volume without recipe-specific data.
        return (rawUnit.trimmingCharacters(in: .whitespacesAndNewlines), 1, "unit:\(normalized)")
    }

    private static func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private static func appendingUnique(_ value: String, to values: [String]?) -> [String] {
        var result = values ?? []
        if !result.contains(value) { result.append(value) }
        return result
    }

    private static func sourceIngredientKey(
        entry: MealPlanEntry,
        recipeID: String,
        index: Int,
        calendar: Calendar
    ) -> String {
        let entryID = entry.id ?? "\(recipeID)|\(calendar.startOfDay(for: entry.date).timeIntervalSince1970)|\(entry.canonicalMealType)|\(entry.plannedServings)"
        return "source:\(entryID)|\(recipeID)|\(index)"
    }
}
