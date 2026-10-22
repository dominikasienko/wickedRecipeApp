//
//  RecipePlannerIOSTests.swift
//  RecipePlannerIOSTests
//
//  Created by Dominika Sieńko on 26/12/2025.
//

import XCTest
@testable import RecipePlannerIOS

final class RecipePlannerIOSTests: XCTestCase {

    // MARK: - UserProfile Tests
    
    /// Tests the age calculation logic based on the birth date.
    func testUserProfileAgeCalculation() {
        // Given: A user born 25 years ago
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -25, to: Date())!
        let profile = UserProfile(
            userId: "test_user",
            firstName: "John",
            lastName: "Doe",
            dateOfBirth: birthDate,
            weight: 80.0,
            height: 180.0,
            gender: "Man",
            activityLevel: "Moderate activity",
            selectedDiets: []
        )
        
        // Then: The age should be exactly 25
        XCTAssertEqual(profile.age, 25, "Age calculation should return the correct number of years.")
    }

    func testNASEMAdultEnergyEquationsForAllSexAndActivityCategories() throws {
        let maleExpected: [(String, Double)] = [
            ("inactive", 2552.67),
            ("lowActive", 2754.87),
            ("active", 2934.62),
            ("veryActive", 3226.67)
        ]
        let femaleExpected: [(String, Double)] = [
            ("inactive", 2079.55),
            ("lowActive", 2243.57),
            ("active", 2381.15),
            ("veryActive", 2614.48)
        ]

        for (activity, expected) in maleExpected {
            let profile = makeProfile(age: 30, sex: "man", activity: activity, weight: 70, height: 175)
            XCTAssertEqual(try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal()), expected, accuracy: 0.01)
        }

        for (activity, expected) in femaleExpected {
            let profile = makeProfile(age: 30, sex: "woman", activity: activity, weight: 65, height: 165)
            XCTAssertEqual(try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal()), expected, accuracy: 0.01)
        }
    }

    func testNASEMAdolescentEquationIncludesGrowthAllowance() throws {
        let maleExpected: [(String, Double)] = [
            ("inactive", 2828.62),
            ("lowActive", 3026.10),
            ("active", 3338.39),
            ("veryActive", 3726.13)
        ]
        let femaleExpected: [(String, Double)] = [
            ("inactive", 2220.09),
            ("lowActive", 2430.96),
            ("active", 2603.65),
            ("veryActive", 2886.96)
        ]

        for (activity, expected) in maleExpected {
            let profile = makeProfile(age: 16, sex: "man", activity: activity, weight: 70, height: 175)
            XCTAssertEqual(try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal()), expected, accuracy: 0.01)
        }

        for (activity, expected) in femaleExpected {
            let profile = makeProfile(age: 16, sex: "woman", activity: activity, weight: 65, height: 165)
            XCTAssertEqual(try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal()), expected, accuracy: 0.01)
        }
    }

    func testNASEMAdultEquationBeginsAtAge19AndUpperAgeBoundaryIsEnforced() throws {
        let age19 = makeProfile(age: 19, sex: "man", activity: "inactive", weight: 70, height: 175)
        XCTAssertEqual(try XCTUnwrap(age19.calculateEstimatedEnergyRequirementKcal()), 2671.8, accuracy: 0.01)

        let age100 = makeProfile(age: 100, sex: "woman", activity: "inactive", weight: 65, height: 165)
        XCTAssertNotNil(age100.calculateEstimatedEnergyRequirementKcal())
        XCTAssertEqual(age100.calculateWaterGoalMl(), 2_000)

        let age101 = makeProfile(age: 101, sex: "woman", activity: "inactive", weight: 65, height: 165)
        XCTAssertNil(age101.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(age101.calculateWaterGoalMl())
    }

    func testEnergyEstimateRecalculatesFromCurrentProfileValues() throws {
        var profile = makeProfile(age: 30, sex: "man", activity: "lowActive", weight: 70, height: 175)
        let initial = try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal())

        profile.weight = 80
        let afterWeightChange = try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNotEqual(initial, afterWeightChange)

        profile.activityLevel = "active"
        let afterActivityChange = try XCTUnwrap(profile.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNotEqual(afterWeightChange, afterActivityChange)
    }

    func testLegacyActivityLabelsMapToUpdatedPALCategories() throws {
        let legacy = makeProfile(age: 30, sex: "man", activity: "Moderate activity", weight: 70, height: 175)
        let canonical = makeProfile(age: 30, sex: "man", activity: "active", weight: 70, height: 175)
        XCTAssertEqual(legacy.calculateEstimatedEnergyRequirementKcal(), canonical.calculateEstimatedEnergyRequirementKcal())
    }

    func testEnergyEstimateDoesNotApplyWeightGoalOrDietMultipliers() throws {
        var baseline = makeProfile(age: 30, sex: "woman", activity: "lowActive", weight: 65, height: 165)
        baseline.weightGoal = "maintain"
        baseline.selectedDiets = ["basic"]

        var weightLossAndVegan = baseline
        weightLossAndVegan.weightGoal = "lose"
        weightLossAndVegan.selectedDiets = ["vegan", "highProtein"]

        XCTAssertEqual(
            try XCTUnwrap(baseline.calculateEstimatedEnergyRequirementKcal()),
            try XCTUnwrap(weightLossAndVegan.calculateEstimatedEnergyRequirementKcal()),
            accuracy: 0.001
        )
    }

    func testUnsupportedOrIneligibleProfilesDoNotReceivePersonalizedTargets() {
        let unsupported = makeProfile(age: 30, sex: "other", activity: "active", weight: 70, height: 175)
        XCTAssertNil(unsupported.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(unsupported.calculateWaterGoalMl())

        var notOptedIn = makeProfile(age: 30, sex: "woman", activity: "active", weight: 65, height: 165)
        notOptedIn.canUseGeneralEstimates = false
        XCTAssertNil(notOptedIn.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(notOptedIn.calculateWaterGoalMl())

        notOptedIn.canUseGeneralEstimates = nil
        XCTAssertNil(notOptedIn.calculateEstimatedEnergyRequirementKcal(), "Migrated profiles without an explicit opt-in remain ineligible.")

        let emptyProfile = UserProfile.empty(userId: "new-user")
        XCTAssertNil(emptyProfile.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(emptyProfile.calculateWaterGoalMl())
    }

    func testInvalidAgeOrMeasurementsDoNotProduceEnergyEstimate() {
        var profile = makeProfile(age: 30, sex: "man", activity: "active", weight: 70, height: 175)
        profile.weight = .nan
        XCTAssertNil(profile.calculateEstimatedEnergyRequirementKcal())

        profile.weight = 70
        profile.height = .infinity
        XCTAssertNil(profile.calculateEstimatedEnergyRequirementKcal())

        profile.height = 175
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -13, to: Date())!
        XCTAssertNil(profile.calculateEstimatedEnergyRequirementKcal())
    }

    func testAgeEligibilityAndConsentAreRequiredForHealthTargets() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let age16DOB = calendar.date(byAdding: .year, value: -16, to: now)!
        let age15DOB = calendar.date(byAdding: .year, value: -15, to: now)!

        XCTAssertTrue(AgeEligibility.isEligible(dateOfBirth: age16DOB, asOf: now, calendar: calendar))
        XCTAssertFalse(AgeEligibility.isEligible(dateOfBirth: age15DOB, asOf: now, calendar: calendar))

        var profile = makeProfile(age: 30, sex: "woman", activity: "active", weight: 65, height: 165)
        XCTAssertNotNil(profile.calculateEstimatedEnergyRequirementKcal())
        profile.healthDataConsentAt = nil
        XCTAssertNil(profile.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(profile.calculateWaterGoalMl())
    }

    func testPrivacyPolicyUsesCanonicalURLWithoutLanguageFragment() {
        XCTAssertEqual(LegalLinks.privacyPolicy.absoluteString, "https://wickedrecipeprivacy.netlify.app/")
        XCTAssertNil(LegalLinks.privacyPolicy.fragment)
    }

    func testAccountDeletionResetsAppPreferencesWithoutClearingOtherDefaults() {
        let suiteName = "AppPreferenceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("pl", forKey: "appLanguagePreference")
        defaults.set("pounds", forKey: "weightUnitPreference")
        defaults.set("keep", forKey: "unrelatedTestValue")

        AppPreferenceStore.resetAfterAccountDeletion(defaults: defaults)

        XCTAssertNil(defaults.object(forKey: "appLanguagePreference"))
        XCTAssertNil(defaults.object(forKey: "weightUnitPreference"))
        XCTAssertEqual(defaults.string(forKey: "unrelatedTestValue"), "keep")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOpenFoodFactsSearchRateLimiterQueuesAfterTenPerMinuteLimit() async throws {
        let limiter = OpenFoodFactsSearchRateLimiter(maximumRequests: 1, interval: 0.05)
        let start = Date()

        try await limiter.waitForTurn()
        try await limiter.waitForTurn()

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.04)
    }

    func testEFSAWaterReferenceIsNotModifiedByWeightActivityOrDiet() throws {
        let woman = makeProfile(age: 30, sex: "woman", activity: "inactive", weight: 50, height: 160)
        var changedInputs = woman
        changedInputs.weight = 120
        changedInputs.activityLevel = "veryActive"
        changedInputs.selectedDiets = ["highProtein", "highFiber", "vegan"]

        XCTAssertEqual(woman.calculateWaterGoalMl(), 2_000)
        XCTAssertEqual(changedInputs.calculateWaterGoalMl(), 2_000)
        XCTAssertEqual(makeProfile(age: 30, sex: "man", activity: "active", weight: 70, height: 175).calculateWaterGoalMl(), 2_500)
    }

    func testAdultMacroGuidanceUsesAMDRRangesNotSingleTargets() throws {
        let profile = makeProfile(age: 30, sex: "man", activity: "inactive", weight: 70, height: 175)
        let macros = try XCTUnwrap(profile.calculateMacrosIfProfileComplete())

        XCTAssertEqual(macros.proteinG.lowerGrams, 2552.67 * 0.10 / 4, accuracy: 0.01)
        XCTAssertEqual(macros.proteinG.upperGrams, 2552.67 * 0.35 / 4, accuracy: 0.01)
        XCTAssertEqual(macros.fatG.lowerGrams, 2552.67 * 0.20 / 9, accuracy: 0.01)
        XCTAssertEqual(macros.carbsG.upperGrams, 2552.67 * 0.65 / 4, accuracy: 0.01)
    }

    func testProfileMeasurementInputAcceptsCommaAndPeriodDecimalSeparators() {
        XCTAssertEqual(ProfileMeasurementInput.parse("70,5"), 70.5)
        XCTAssertEqual(ProfileMeasurementInput.parse("70.5"), 70.5)
        XCTAssertEqual(ProfileMeasurementInput.parse("1.234,5"), 1234.5)
        XCTAssertNil(ProfileMeasurementInput.parse(""))
        XCTAssertNil(ProfileMeasurementInput.parse("not a number"))
    }

    // MARK: - Recipe Model Tests
    
    /// Tests that ingredients are correctly formatted for the Nutrition API.
    func testIngredientDescriptionForAPI() {
        XCTAssertEqual(Ingredient(name: "Flour", quantity: 1.55, unit: "cups").descriptionForAPI, "1.55 cups Flour")
        XCTAssertEqual(Ingredient(name: "Salt", quantity: 0.25, unit: "tsp").descriptionForAPI, "0.25 tsp Salt")
        XCTAssertEqual(Ingredient(name: "Oil", quantity: 2.5, unit: "tbsp").descriptionForAPI, "2.5 tbsp Oil")
        XCTAssertEqual(Ingredient(name: "Eggs", quantity: 2, unit: "piece").descriptionForAPI, "2 piece Eggs")
    }

    @MainActor
    func testIngredientQuantityInputSupportsTwoDecimalsAndLocaleSeparators() throws {
        let germanLocale = Locale(identifier: "de_DE")
        let englishLocale = Locale(identifier: "en_US")

        let commaInput = IngredientQuantityFormatter.sanitizedInput("0.25", locale: germanLocale)
        XCTAssertEqual(commaInput, "0,25")
        XCTAssertEqual(IngredientQuantityFormatter.parsedInput(commaInput, locale: germanLocale), 0.25)

        let periodInput = IngredientQuantityFormatter.sanitizedInput("0,25", locale: englishLocale)
        XCTAssertEqual(periodInput, "0.25")
        XCTAssertEqual(IngredientQuantityFormatter.parsedInput(periodInput, locale: englishLocale), 0.25)

        XCTAssertEqual(IngredientQuantityFormatter.sanitizedInput("1.237", locale: englishLocale), "1.23")
        XCTAssertEqual(IngredientQuantityFormatter.formatted(0.25, locale: germanLocale), "0,25")

        let trailingZeroInput = IngredientQuantityFormatter.sanitizedInput("2.50", locale: englishLocale)
        XCTAssertEqual(trailingZeroInput, "2.50")
        XCTAssertEqual(IngredientQuantityFormatter.parsedInput(trailingZeroInput, locale: englishLocale), 2.5)
        XCTAssertEqual(IngredientQuantityFormatter.formatted(2.5, locale: englishLocale), "2.5")
        XCTAssertEqual(IngredientQuantityFormatter.formatted(1.25, locale: englishLocale), "1.25")

        let ingredient = Ingredient(name: "Salt", quantity: 0.25, unit: "tsp")
        let data = try JSONEncoder().encode(ingredient)
        let decoded = try JSONDecoder().decode(Ingredient.self, from: data)
        XCTAssertEqual(decoded.quantity, 0.25)
        XCTAssertEqual(decoded.unit, "tsp")
    }

    func testRecipeSelectionStateSupportsMultiSelectCancelAndPruning() {
        var selection = RecipeSelectionState()
        selection.begin(selecting: "recipe-1")
        XCTAssertTrue(selection.isActive)
        XCTAssertEqual(selection.selectedRecipeIDs, ["recipe-1"])

        selection.toggle("recipe-2")
        XCTAssertEqual(selection.selectedRecipeIDs, ["recipe-1", "recipe-2"])
        selection.toggle("recipe-1")
        XCTAssertEqual(selection.selectedRecipeIDs, ["recipe-2"])

        selection.retain(validRecipeIDs: ["recipe-2", "recipe-3"])
        XCTAssertEqual(selection.selectedRecipeIDs, ["recipe-2"])

        selection.exit()
        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.selectedRecipeIDs.isEmpty)
    }

    func testRecipeDeletionValidatesOwnershipAndDeduplicatesIDs() throws {
        let ownedRecipe = makeRecipe(id: "recipe-1", userId: "owner")
        let anotherOwnedCopy = makeRecipe(id: "recipe-1", userId: "owner")
        let ids = try RecipeManager.validatedRecipeIDs(
            recipes: [ownedRecipe, anotherOwnedCopy],
            authenticatedUserID: "owner"
        )
        XCTAssertEqual(ids, ["recipe-1"])

        XCTAssertThrowsError(
            try RecipeManager.validatedRecipeIDs(
                recipes: [ownedRecipe],
                authenticatedUserID: "another-user"
            )
        ) { error in
            XCTAssertEqual(error as? RecipeDeletionError, .ownershipMismatch)
        }
    }

    /// Tests the total intake calculation in a WaterRecord.
    func testWaterRecordTotalIntake() {
        // Given: A record with multiple entries
        let entries = [
            WaterEntry(amountMl: 250),
            WaterEntry(amountMl: 500)
        ]
        let record = WaterRecord(userId: "u1", entries: entries, amountMl: 0, timestamp: Date())
        
        // Then: Total should be sum of entries
        XCTAssertEqual(record.totalIntakeML, 750, "Total logged volume should correctly sum all entries.")
        let legacyFactoredEntry = WaterEntry(amountMl: 1_000, hydrationFactor: 0.5)
        let legacyFactoredRecord = WaterRecord(
            userId: "u1",
            entries: [legacyFactoredEntry],
            amountMl: 1_000,
            timestamp: Date()
        )
        XCTAssertEqual(legacyFactoredRecord.totalIntakeML, 1_000, "Legacy factors must not change logged drink volume.")
    }
    
    // MARK: - Date Extension Tests
    
    /// Tests the startOfDay extension used in the Meal Planner.
    func testDateStartOfDay() {
        // Given: A specific time during the day
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let someTime = formatter.date(from: "2025/11/18 15:45")!
        
        // When: Getting start of day
        let start = someTime.startOfDay
        
        // Then: Time components should be zero
        let components = Calendar.current.dateComponents([.hour, .minute], from: start)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    private func makeRecipe(id: String, userId: String) -> Recipe {
        Recipe(
            id: id,
            userId: userId,
            name: "Test recipe",
            category: "BASICS",
            preparationTimeMinutes: 10,
            servings: 1,
            ingredients: [],
            instructions: []
        )
    }

    private func makeProfile(
        age: Int,
        sex: String,
        activity: String,
        weight: Double,
        height: Double
    ) -> UserProfile {
        UserProfile(
            userId: "health-test",
            firstName: "Test",
            lastName: "User",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -age, to: Date())!,
            weight: weight,
            height: height,
            gender: sex,
            activityLevel: activity,
            selectedDiets: [],
            weightGoal: "maintain",
            canUseGeneralEstimates: true,
            ageEligibilityConfirmedAt: Date(),
            healthDataConsentAt: Date(),
            privacyPolicyVersion: LegalLinks.privacyPolicyVersion
        )
    }
}
