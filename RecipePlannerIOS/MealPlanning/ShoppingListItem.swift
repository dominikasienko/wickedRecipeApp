import Foundation

/// An editable shopping-list row. Optional generation metadata makes older local
/// list data decode safely while supporting reconciliation with a meal plan.
struct ShoppingListItem: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var isCompleted: Bool
    var isManuallyAdded: Bool
    var recipeSources: [String]?
    var sourceRecipeIDs: [String]?
    var sourceMealEntryIDs: [String]?
    var generationKey: String?
    var ingredientIdentityKey: String?
    var isManuallyEdited: Bool
    var isExcludedFromGeneration: Bool
    var quantityNote: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String,
        isCompleted: Bool = false,
        isManuallyAdded: Bool = false,
        recipeSources: [String]? = nil,
        sourceRecipeIDs: [String]? = nil,
        sourceMealEntryIDs: [String]? = nil,
        generationKey: String? = nil,
        ingredientIdentityKey: String? = nil,
        isManuallyEdited: Bool = false,
        isExcludedFromGeneration: Bool = false,
        quantityNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isCompleted = isCompleted
        self.isManuallyAdded = isManuallyAdded
        self.recipeSources = recipeSources
        self.sourceRecipeIDs = sourceRecipeIDs
        self.sourceMealEntryIDs = sourceMealEntryIDs
        self.generationKey = generationKey
        self.ingredientIdentityKey = ingredientIdentityKey
        self.isManuallyEdited = isManuallyEdited
        self.isExcludedFromGeneration = isExcludedFromGeneration
        self.quantityNote = quantityNote
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, isCompleted, isManuallyAdded, recipeSources
        case sourceRecipeIDs, sourceMealEntryIDs, generationKey, ingredientIdentityKey
        case isManuallyEdited, isExcludedFromGeneration, quantityNote
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        quantity = try values.decodeIfPresent(Double.self, forKey: .quantity) ?? 0
        unit = try values.decodeIfPresent(String.self, forKey: .unit) ?? ""
        isCompleted = try values.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isManuallyAdded = try values.decodeIfPresent(Bool.self, forKey: .isManuallyAdded) ?? false
        recipeSources = try values.decodeIfPresent([String].self, forKey: .recipeSources)
        sourceRecipeIDs = try values.decodeIfPresent([String].self, forKey: .sourceRecipeIDs)
        sourceMealEntryIDs = try values.decodeIfPresent([String].self, forKey: .sourceMealEntryIDs)
        generationKey = try values.decodeIfPresent(String.self, forKey: .generationKey)
        ingredientIdentityKey = try values.decodeIfPresent(String.self, forKey: .ingredientIdentityKey)
        isManuallyEdited = try values.decodeIfPresent(Bool.self, forKey: .isManuallyEdited) ?? false
        isExcludedFromGeneration = try values.decodeIfPresent(Bool.self, forKey: .isExcludedFromGeneration) ?? false
        quantityNote = try values.decodeIfPresent(String.self, forKey: .quantityNote)
    }

    var amountDescription: String? {
        guard quantity.isFinite, quantity > 0 else {
            let detail = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? nil : detail
        }

        let formattedQuantity: String
        if quantity.rounded() == quantity, quantity < Double(Int.max) {
            formattedQuantity = String(Int(quantity))
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 3
            formatter.minimumFractionDigits = 0
            formattedQuantity = formatter.string(from: NSNumber(value: quantity)) ?? String(quantity)
        }

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = trimmedUnit.isEmpty ? formattedQuantity : "\(formattedQuantity) \(trimmedUnit)"
        return amount
    }

    var description: String {
        let detail = [amountDescription, quantityNote].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
        return detail.isEmpty ? name : "\(name): \(detail)"
    }
}
