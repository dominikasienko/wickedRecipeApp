import Foundation

enum LegalLinks {
    static let privacyPolicy = URL(string: "https://wickedrecipeprivacy.netlify.app/")!
    static let termsOfUse: URL? = nil
    static let privacyPolicyVersion = "2026-10-21"
    nonisolated static let contactEmail = "dominika.sienko@icloud.com"
    static let openFoodFacts = URL(string: "https://world.openfoodfacts.org/")!
    static let usdaFoodDataCentral = URL(string: "https://fdc.nal.usda.gov/")!
}

enum AgeEligibility {
    static let minimumAge = 16
    static let maximumAge = 100

    static func age(on dateOfBirth: Date, asOf now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: dateOfBirth, to: now).year ?? 0
    }

    static func isEligible(dateOfBirth: Date, asOf now: Date = Date(), calendar: Calendar = .current) -> Bool {
        (minimumAge...maximumAge).contains(age(on: dateOfBirth, asOf: now, calendar: calendar))
    }
}

enum AppPreferenceStore {
    private static let accountPreferenceKeys = [
        "waterReminderEnabled",
        "waterReminderIntervalHours",
        "waterReminderQuietHoursEnabled",
        "waterReminderQuietStartHour",
        "waterReminderQuietEndHour",
        "weightUnitPreference",
        "heightUnitPreference",
        "volumeUnitPreference",
        "energyUnitPreference",
        "clockFormatPreference",
        "weekStartDay",
        "defaultMealType",
        "shoppingIncludeManualItems",
        "shoppingPreserveCompletedState",
        "hydrationDefaultDrinkTypeRaw",
        "hydrationDefaultVolumeMl",
        "hydrationPreferredMilkRaw",
        "hydrationFavoriteDrinkIDs",
        "selectedWickedCharacter",
        "highContrastMode",
        "reduceMotionEnabled",
        "hapticsEnabled",
        "appLanguagePreference",
        "syncLastRefreshEpoch",
        "ShoppingListItems",
        "ShoppingListDates"
    ]

    static func resetAfterAccountDeletion(defaults: UserDefaults = .standard) {
        accountPreferenceKeys.forEach(defaults.removeObject(forKey:))
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("ShoppingListItems.") || $0.hasPrefix("ShoppingListDates.") }
            .forEach(defaults.removeObject(forKey:))
    }
}
