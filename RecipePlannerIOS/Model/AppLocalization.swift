import Foundation
import SwiftUI

enum AppLocalization {
    static let supportedLanguageIdentifiers = ["en", "de", "es", "fr", "it", "pl"]

    // Keep view-facing values as keys so SwiftUI resolves them using the current environment locale.
    static func key(_ key: LocalizedStringKey) -> LocalizedStringKey {
        key
    }

    static func resolved(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }
}

struct AppLocalizedOption: Identifiable, Hashable {
    let id: String
    let localizationKey: String
    let legacyValues: [String]

    init(id: String, localizationKey: String, legacyValues: [String] = []) {
        self.id = id
        self.localizationKey = localizationKey
        self.legacyValues = legacyValues
    }

    var title: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }

    func resolvedTitle(locale: Locale) -> String {
        AppLocalization.resolved(String.LocalizationValue(localizationKey), locale: locale)
    }
}

enum AppOptionCatalog {
    static let genders = [
        AppLocalizedOption(id: "man", localizationKey: "Male reference category", legacyValues: ["Man", "Male"]),
        AppLocalizedOption(id: "woman", localizationKey: "Female reference category", legacyValues: ["Woman", "Female"]),
        AppLocalizedOption(id: "other", localizationKey: "Other (no supported equation)", legacyValues: ["Other", "Unidentified"])
    ]

    static let activityLevels = [
        AppLocalizedOption(
            id: "inactive",
            localizationKey: "Inactive (daily living activity only)",
            legacyValues: ["sedentary", "No activity", "No activity (sedentary lifestyle)"]
        ),
        AppLocalizedOption(
            id: "lowActive",
            localizationKey: "Low active (some additional movement)",
            legacyValues: ["low", "Low activity (1-2 workouts per week)"]
        ),
        AppLocalizedOption(
            id: "active",
            localizationKey: "Active (more daily or recreational activity)",
            legacyValues: ["moderate", "Moderate activity", "Moderate activity (3-5 workouts per week)"]
        ),
        AppLocalizedOption(
            id: "veryActive",
            localizationKey: "Very active (vigorous work or recreation)",
            legacyValues: [
                "high", "veryHigh", "High activity", "Very high activity",
                "High activity (daily intense workouts)", "Very high activity (twice a day)"
            ]
        )
    ]

    static let dietOptions = [
        AppLocalizedOption(id: "basic", localizationKey: "Basic"),
        AppLocalizedOption(id: "easyDigest", localizationKey: "Easy to digest"),
        AppLocalizedOption(id: "vegan", localizationKey: "Vegan"),
        AppLocalizedOption(id: "vegetarian", localizationKey: "Vegetarian"),
        AppLocalizedOption(id: "highProtein", localizationKey: "High protein"),
        AppLocalizedOption(id: "lowProtein", localizationKey: "Low protein"),
        AppLocalizedOption(id: "glutenFree", localizationKey: "Gluten-free"),
        AppLocalizedOption(id: "highFiber", localizationKey: "High fiber")
    ]

    static let weightGoals = [
        AppLocalizedOption(id: "lose", localizationKey: "Lose weight"),
        AppLocalizedOption(id: "maintain", localizationKey: "Maintain weight"),
        AppLocalizedOption(id: "gain", localizationKey: "Gain weight")
    ]

    static let mealTypes = [
        AppLocalizedOption(id: "breakfast", localizationKey: "Breakfast"),
        AppLocalizedOption(id: "lunch", localizationKey: "Lunch"),
        AppLocalizedOption(id: "dinner", localizationKey: "Dinner"),
        AppLocalizedOption(id: "snack", localizationKey: "Snack")
    ]

    static let recipeCategories = [
        AppLocalizedOption(id: "BASICS", localizationKey: "BASICS"),
        AppLocalizedOption(id: "BREAKFAST & BRUNCH", localizationKey: "BREAKFAST & BRUNCH"),
        AppLocalizedOption(id: "APPETIZERS, SIDES & SALADS", localizationKey: "APPETIZERS, SIDES & SALADS"),
        AppLocalizedOption(id: "SOUP, STEW & CURRY", localizationKey: "SOUP, STEW & CURRY"),
        AppLocalizedOption(id: "LUNCH & DINNER", localizationKey: "LUNCH & DINNER"),
        AppLocalizedOption(id: "PASTA & GNOCCHI", localizationKey: "PASTA & GNOCCHI"),
        AppLocalizedOption(id: "QUICK & EASY", localizationKey: "QUICK & EASY"),
        AppLocalizedOption(id: "PIZZA, SANDWICHES & BURGER", localizationKey: "PIZZA, SANDWICHES & BURGER"),
        AppLocalizedOption(id: "CAKE", localizationKey: "CAKE"),
        AppLocalizedOption(id: "FINGERFOOD & SNACKS", localizationKey: "FINGERFOOD & SNACKS"),
        AppLocalizedOption(id: "SWEETS & DESSERT", localizationKey: "SWEETS & DESSERT")
    ]

    static func canonicalValue(for storedValue: String, in options: [AppLocalizedOption]) -> String {
        option(for: storedValue, in: options)?.id ?? storedValue
    }

    static func displayName(
        for storedValue: String,
        in options: [AppLocalizedOption],
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        option(for: storedValue, in: options)?.resolvedTitle(locale: locale) ?? storedValue
    }

    static func localizationKey(for storedValue: String, in options: [AppLocalizedOption]) -> String? {
        option(for: storedValue, in: options)?.localizationKey
    }

    static func localizedTitle(for storedValue: String, in options: [AppLocalizedOption]) -> LocalizedStringKey {
        guard let key = localizationKey(for: storedValue, in: options) else {
            return LocalizedStringKey(storedValue)
        }
        return LocalizedStringKey(key)
    }

    static func contains(_ storedValue: String, in options: [AppLocalizedOption]) -> Bool {
        option(for: storedValue, in: options) != nil
    }

    private static func option(for storedValue: String, in options: [AppLocalizedOption]) -> AppLocalizedOption? {
        let normalizedStoredValue = normalized(storedValue)
        guard !normalizedStoredValue.isEmpty else { return nil }

        return options.first { option in
            knownValues(for: option).contains(normalizedStoredValue)
        }
    }

    private static func knownValues(for option: AppLocalizedOption) -> Set<String> {
        let localizedValues = AppLocalization.supportedLanguageIdentifiers.map { identifier in
            AppLocalization.resolved(
                String.LocalizationValue(option.localizationKey),
                locale: Locale(identifier: identifier)
            )
        }

        return Set(([option.id, option.localizationKey] + option.legacyValues + localizedValues).map(normalized))
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
