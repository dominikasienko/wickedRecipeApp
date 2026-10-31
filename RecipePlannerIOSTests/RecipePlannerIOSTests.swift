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
        XCTAssertEqual(age100.hydrationAssessment()?.efsaReference?.totalWaterMlPerDay, 2_000)

        let age101 = makeProfile(age: 101, sex: "woman", activity: "inactive", weight: 65, height: 165)
        XCTAssertNil(age101.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(age101.hydrationAssessment())
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
        XCTAssertNil(unsupported.hydrationAssessment()?.efsaReference)

        var notOptedIn = makeProfile(age: 30, sex: "woman", activity: "active", weight: 65, height: 165)
        notOptedIn.canUseGeneralEstimates = false
        XCTAssertNil(notOptedIn.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(notOptedIn.hydrationAssessment())

        notOptedIn.canUseGeneralEstimates = nil
        XCTAssertNil(notOptedIn.calculateEstimatedEnergyRequirementKcal(), "Migrated profiles without an explicit opt-in remain ineligible.")

        let emptyProfile = UserProfile.empty(userId: "new-user")
        XCTAssertNil(emptyProfile.calculateEstimatedEnergyRequirementKcal())
        XCTAssertNil(emptyProfile.hydrationAssessment())
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
        XCTAssertNil(profile.hydrationAssessment())
    }

    func testProfileImageEditStatePreservesReplacesAndRemovesExplicitly() throws {
        var profile = makeProfile(age: 30, sex: "woman", activity: "active", weight: 65, height: 165)
        profile.profileImageURL = "https://storage.example.com/users/test/profile.jpg"

        let unchanged = try XCTUnwrap(ProfileImageEditState.unchanged.applying(to: profile))
        XCTAssertEqual(unchanged.profileImageURL, profile.profileImageURL)

        let replaced = try XCTUnwrap(
            ProfileImageEditState.replacement.applying(to: profile, replacementURL: "https://storage.example.com/users/test/new-profile.jpg")
        )
        XCTAssertEqual(replaced.profileImageURL, "https://storage.example.com/users/test/new-profile.jpg")
        XCTAssertNil(ProfileImageEditState.replacement.applying(to: profile))

        let removed = try XCTUnwrap(ProfileImageEditState.removal.applying(to: profile))
        XCTAssertNil(removed.profileImageURL)

        profile.profileImageURL = nil
        XCTAssertNil(ProfileImageEditState.removal.applying(to: profile)?.profileImageURL)
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

    func testEFSAWaterReferenceIsSeparateFromWeightActivityAndDietEstimates() throws {
        let woman = makeProfile(age: 30, sex: "woman", activity: "inactive", weight: 50, height: 160)
        var changedInputs = woman
        changedInputs.weight = 120
        changedInputs.activityLevel = "veryActive"
        changedInputs.selectedDiets = ["highProtein", "highFiber", "vegan"]

        XCTAssertEqual(woman.hydrationAssessment()?.efsaReference?.totalWaterMlPerDay, 2_000)
        XCTAssertEqual(changedInputs.hydrationAssessment()?.efsaReference?.totalWaterMlPerDay, 2_000)
        XCTAssertEqual(
            makeProfile(age: 30, sex: "man", activity: "active", weight: 70, height: 175)
                .hydrationAssessment()?.efsaReference?.totalWaterMlPerDay,
            2_500
        )
    }

    func testEFSAWaterReferenceValuesAndSupportedLifeStageAdjustments() throws {
        XCTAssertEqual(HydrationCalculationService.efsaReference(sex: .female)?.totalWaterMlPerDay, 2_000)
        XCTAssertEqual(HydrationCalculationService.efsaReference(sex: .male)?.totalWaterMlPerDay, 2_500)

        let pregnancy = try XCTUnwrap(
            HydrationCalculationService.efsaReference(sex: .female, lifeStage: .pregnancy)
        )
        let lactation = try XCTUnwrap(
            HydrationCalculationService.efsaReference(sex: .female, lifeStage: .lactation)
        )
        XCTAssertEqual(pregnancy.totalWaterMlPerDay, 2_300)
        if case .pregnancy = pregnancy.lifeStage {
            // Expected life stage.
        } else {
            XCTFail("Pregnancy adjustment should retain its life-stage provenance.")
        }
        XCTAssertEqual(lactation.totalWaterMlPerDay, 2_700)
        if case .lactation = lactation.lifeStage {
            // Expected life stage.
        } else {
            XCTFail("Lactation adjustment should retain its life-stage provenance.")
        }
        XCTAssertNil(HydrationCalculationService.efsaReference(sex: .male, lifeStage: .pregnancy))
        XCTAssertNil(HydrationCalculationService.efsaReference(sex: .male, lifeStage: .lactation))
    }

    func testWeightBasedFluidEstimateUsesThirtyMlPerKgFor60To80Kg() throws {
        let expected: [(weight: Double, milliliters: Double)] = [
            (60, 1_800),
            (70, 2_100),
            (80, 2_400)
        ]

        for item in expected {
            let profile = makeProfile(
                age: 30,
                sex: "woman",
                activity: "inactive",
                weight: item.weight,
                height: 180
            )
            let estimate = try XCTUnwrap(profile.hydrationAssessment()?.dailyFluidEstimate)
            XCTAssertEqual(estimate.estimatedMlPerDay, item.milliliters)
            XCTAssertEqual(estimate.weightKgUsed, item.weight)
            if case .currentBodyWeight = estimate.weightSource {
                // Current weight is appropriate below BMI 25.
            } else {
                XCTFail("Expected the current body weight to be used for \(item.weight) kg.")
            }
        }
    }

    func testOverweightFluidEstimateRequiresAValidProvidedReferenceWeight() throws {
        var profile = makeProfile(age: 30, sex: "woman", activity: "inactive", weight: 100, height: 170)
        var assessment = try XCTUnwrap(profile.hydrationAssessment())
        XCTAssertNil(assessment.dailyFluidEstimate)
        XCTAssertEqual(assessment.fluidEstimateUnavailableReason, .referenceWeightRequiredForBMI25OrHigher)

        profile.referenceWeightKg = 75
        assessment = try XCTUnwrap(profile.hydrationAssessment())
        let estimate = try XCTUnwrap(assessment.dailyFluidEstimate)
        XCTAssertEqual(estimate.estimatedMlPerDay, 2_250)
        XCTAssertEqual(estimate.weightKgUsed, 75)
        if case .providedReferenceWeight = estimate.weightSource {
            // The supplied reference weight is used for BMI 25 or higher.
        } else {
            XCTFail("Expected the supplied reference weight to be used.")
        }

        for invalidReferenceWeight in [0, -1, 29.9, 100, 301, .nan, .infinity] {
            profile.referenceWeightKg = invalidReferenceWeight
            let invalidAssessment = try XCTUnwrap(profile.hydrationAssessment())
            XCTAssertNil(invalidAssessment.dailyFluidEstimate, "Invalid reference weight: \(invalidReferenceWeight)")
            XCTAssertEqual(invalidAssessment.fluidEstimateUnavailableReason, .validReferenceWeightRequired)
        }
    }

    func testInvalidBodyMeasurementsDoNotProduceWeightBasedFluidEstimate() throws {
        var profile = makeProfile(age: 30, sex: "woman", activity: "inactive", weight: 70, height: 175)

        for invalidWeight in [0, -1, 29.9, 300.1, .nan, .infinity] {
            profile.weight = invalidWeight
            let assessment = try XCTUnwrap(profile.hydrationAssessment())
            XCTAssertNil(assessment.dailyFluidEstimate, "Invalid current weight: \(invalidWeight)")
            XCTAssertEqual(assessment.fluidEstimateUnavailableReason, .validHeightAndWeightRequired)
        }

        profile.weight = 70
        for invalidHeight in [0, -1, 119.9, 250.1, .nan, .infinity] {
            profile.height = invalidHeight
            let assessment = try XCTUnwrap(profile.hydrationAssessment())
            XCTAssertNil(assessment.dailyFluidEstimate, "Invalid height: \(invalidHeight)")
            XCTAssertEqual(assessment.fluidEstimateUnavailableReason, .validHeightAndWeightRequired)
        }
    }

    func testAdolescentReceivesEFSAReferenceButNoAdultWeightEstimate() throws {
        let profile = makeProfile(age: 16, sex: "woman", activity: "active", weight: 55, height: 165)
        let assessment = try XCTUnwrap(profile.hydrationAssessment())

        XCTAssertEqual(assessment.efsaReference?.totalWaterMlPerDay, 2_000)
        XCTAssertNil(assessment.dailyFluidEstimate)
        XCTAssertEqual(assessment.fluidEstimateUnavailableReason, .adultEstimateOnly)
    }

    func testHydrationAssessmentRecalculatesWithProfileChangesWithoutActivityMultiplier() throws {
        var profile = makeProfile(age: 30, sex: "woman", activity: "inactive", weight: 70, height: 180)
        let initial = try XCTUnwrap(profile.hydrationAssessment())

        profile.activityLevel = "veryActive"
        let changedActivity = try XCTUnwrap(profile.hydrationAssessment())
        XCTAssertEqual(changedActivity.dailyFluidEstimate?.estimatedMlPerDay, initial.dailyFluidEstimate?.estimatedMlPerDay)
        XCTAssertEqual(changedActivity.efsaReference?.totalWaterMlPerDay, initial.efsaReference?.totalWaterMlPerDay)

        profile.weight = 72
        let changedWeight = try XCTUnwrap(profile.hydrationAssessment())
        XCTAssertEqual(changedWeight.dailyFluidEstimate?.estimatedMlPerDay, 2_160)

        profile.gender = "man"
        let changedReferenceCategory = try XCTUnwrap(profile.hydrationAssessment())
        XCTAssertEqual(changedReferenceCategory.efsaReference?.totalWaterMlPerDay, 2_500)
        XCTAssertEqual(changedReferenceCategory.dailyFluidEstimate?.estimatedMlPerDay, 2_160)
    }

    func testExerciseHydrationEstimateUsesMeasuredSessionInputs() throws {
        let input = ExerciseHydrationInput(
            preExerciseWeightKg: 70,
            postExerciseWeightKg: 69.5,
            durationMinutes: 60,
            fluidConsumedMl: 500,
            urineOutputMl: 100
        )
        let estimate = try XCTUnwrap(ExerciseHydrationCalculator.estimate(from: input))

        XCTAssertEqual(estimate.estimatedSweatLossLiters, 0.9, accuracy: 0.0001)
        XCTAssertEqual(estimate.estimatedSweatRateLitersPerHour, 0.9, accuracy: 0.0001)
        XCTAssertEqual(estimate.bodyMassLossLiters, 0.5, accuracy: 0.0001)
        XCTAssertEqual(estimate.recoveryFluidRangeMl?.lowerBound, 500)
        XCTAssertEqual(estimate.recoveryFluidRangeMl?.upperBound, 600)

        let shorterSession = ExerciseHydrationInput(
            preExerciseWeightKg: 70,
            postExerciseWeightKg: 69.5,
            durationMinutes: 30,
            fluidConsumedMl: 500,
            urineOutputMl: 100
        )
        XCTAssertEqual(
            try XCTUnwrap(ExerciseHydrationCalculator.estimate(from: shorterSession)).estimatedSweatRateLitersPerHour,
            1.8,
            accuracy: 0.0001
        )
    }

    func testExerciseHydrationAccountsForFluidAndUrineAndOnlyShowsRecoveryWithMassLoss() throws {
        let input = ExerciseHydrationInput(
            preExerciseWeightKg: 70,
            postExerciseWeightKg: 70,
            durationMinutes: 30,
            fluidConsumedMl: 250,
            urineOutputMl: 50
        )
        let estimate = try XCTUnwrap(ExerciseHydrationCalculator.estimate(from: input))
        XCTAssertEqual(estimate.estimatedSweatLossLiters, 0.2, accuracy: 0.0001)
        XCTAssertEqual(estimate.estimatedSweatRateLitersPerHour, 0.4, accuracy: 0.0001)
        XCTAssertNil(estimate.recoveryFluidRangeMl)

        let noPositiveSweatLoss = ExerciseHydrationInput(
            preExerciseWeightKg: 70,
            postExerciseWeightKg: 70,
            durationMinutes: 30,
            fluidConsumedMl: 0,
            urineOutputMl: 100
        )
        XCTAssertNil(ExerciseHydrationCalculator.estimate(from: noPositiveSweatLoss))
    }

    func testExerciseHydrationRejectsInvalidOrIncompleteInputs() {
        let valid = ExerciseHydrationInput(
            preExerciseWeightKg: 70,
            postExerciseWeightKg: 69.5,
            durationMinutes: 60,
            fluidConsumedMl: 0,
            urineOutputMl: 0
        )
        XCTAssertNotNil(ExerciseHydrationCalculator.estimate(from: valid))

        let invalidInputs = [
            ExerciseHydrationInput(preExerciseWeightKg: 70, postExerciseWeightKg: 69, durationMinutes: 0, fluidConsumedMl: 0, urineOutputMl: 0),
            ExerciseHydrationInput(preExerciseWeightKg: 70, postExerciseWeightKg: 69, durationMinutes: -1, fluidConsumedMl: 0, urineOutputMl: 0),
            ExerciseHydrationInput(preExerciseWeightKg: 70, postExerciseWeightKg: 69, durationMinutes: 60, fluidConsumedMl: -1, urineOutputMl: 0),
            ExerciseHydrationInput(preExerciseWeightKg: 70, postExerciseWeightKg: 69, durationMinutes: 60, fluidConsumedMl: 0, urineOutputMl: -1),
            ExerciseHydrationInput(preExerciseWeightKg: .nan, postExerciseWeightKg: 69, durationMinutes: 60, fluidConsumedMl: 0, urineOutputMl: 0),
            ExerciseHydrationInput(preExerciseWeightKg: 70, postExerciseWeightKg: .infinity, durationMinutes: 60, fluidConsumedMl: 0, urineOutputMl: 0),
            ExerciseHydrationInput(preExerciseWeightKg: 29, postExerciseWeightKg: 28, durationMinutes: 60, fluidConsumedMl: 0, urineOutputMl: 0)
        ]

        for input in invalidInputs {
            XCTAssertNil(ExerciseHydrationCalculator.estimate(from: input))
        }
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

    func testWaterDailyTotalsSeparateEntriesByTimestampAcrossDocuments() throws {
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let october22 = try waterTestDate("2026-10-22T12:00:00Z")
        let october23 = try waterTestDate("2026-10-23T12:00:00Z")

        // The third entry reproduces the legacy midnight bug: it has an October 23
        // timestamp but was saved in the October 22 document.
        let records = [makeWaterRecord(
            documentID: "2026-10-22",
            entries: [
                WaterEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!, amountMl: 40,
                           timestamp: try waterTestDate("2026-10-22T09:00:00Z")),
                WaterEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000150")!, amountMl: 150,
                           timestamp: try waterTestDate("2026-10-22T15:00:00Z")),
                WaterEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!, amountMl: 150,
                           timestamp: try waterTestDate("2026-10-23T08:00:00Z"))
            ]
        )]

        XCTAssertEqual(WaterIntakeDay.total(in: records, on: october22, calendar: calendar), 190)
        XCTAssertEqual(WaterIntakeDay.total(in: records, on: october23, calendar: calendar), 150)
        XCTAssertEqual(WaterIntakeDay.entries(in: records).reduce(0) { $0 + $1.amountMl }, 340)
        XCTAssertEqual(WaterIntakeDay.documentID(for: october22, calendar: calendar), "2026-10-22")
        XCTAssertEqual(WaterIntakeDay.documentID(for: october23, calendar: calendar), "2026-10-23")
    }

    func testWaterLogOnNextDayUsesNewDocumentAndPreservesPreviousDay() throws {
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let october22 = try waterTestDate("2026-10-22T12:00:00Z")
        let october23 = try waterTestDate("2026-10-23T08:00:00Z")
        let previousEntries = [
            WaterEntry(amountMl: 40, timestamp: try waterTestDate("2026-10-22T09:00:00Z")),
            WaterEntry(amountMl: 150, timestamp: try waterTestDate("2026-10-22T15:00:00Z"))
        ]
        let recordsBeforeAdd = [makeWaterRecord(documentID: "2026-10-22", entries: previousEntries)]
        let newEntry = WaterEntry(amountMl: 150, timestamp: october23)
        let destinationID = WaterIntakeDay.documentID(for: newEntry.timestamp, calendar: calendar)
        let recordsAfterAdd = WaterIntakeDay.appending(
            newEntry,
            documentID: destinationID,
            to: recordsBeforeAdd,
            userId: "water-test-user"
        )

        XCTAssertEqual(destinationID, "2026-10-23")
        XCTAssertNotEqual(destinationID, recordsBeforeAdd[0].id)
        XCTAssertEqual(recordsBeforeAdd[0].entries, previousEntries)
        XCTAssertEqual(WaterIntakeDay.total(in: recordsAfterAdd, on: october22, calendar: calendar), 190)
        XCTAssertEqual(WaterIntakeDay.total(in: recordsAfterAdd, on: october23, calendar: calendar), 150)
    }

    func testWaterDailyTotalCountsUniqueSameDayEntriesOnceAndSwitchesDates() throws {
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let october22 = try waterTestDate("2026-10-22T12:00:00Z")
        let october23 = try waterTestDate("2026-10-23T12:00:00Z")
        let repeated = WaterEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000250")!,
            amountMl: 250,
            timestamp: try waterTestDate("2026-10-22T10:00:00Z")
        )
        let records = [
            makeWaterRecord(documentID: "2026-10-22", entries: [
                repeated,
                repeated,
                WaterEntry(amountMl: 40, timestamp: try waterTestDate("2026-10-22T11:00:00Z")),
                WaterEntry(amountMl: 150, timestamp: try waterTestDate("2026-10-23T11:00:00Z"))
            ])
        ]

        XCTAssertEqual(WaterIntakeDay.total(in: records, on: october22, calendar: calendar), 290)
        XCTAssertEqual(WaterIntakeDay.total(in: records, on: october23, calendar: calendar), 150)
        XCTAssertEqual(WaterIntakeDay.total(in: records, on: october22, calendar: calendar), 290)
    }

    func testWaterDayKeysAndTotalsRespectLocalMidnightAndDaylightSavingTime() throws {
        let timezone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let calendar = waterTestCalendar(timeZone: timezone)
        let beforeMidnight = try waterTestDate("2026-03-08T07:59:59Z")
        let afterMidnight = try waterTestDate("2026-03-08T08:00:00Z")
        let afterDaylightSavingTransition = try waterTestDate("2026-03-08T10:00:00Z")
        let start = try XCTUnwrap(WaterIntakeDay.interval(containing: afterMidnight, calendar: calendar))

        XCTAssertEqual(WaterIntakeDay.documentID(for: beforeMidnight, calendar: calendar), "2026-03-07")
        XCTAssertEqual(WaterIntakeDay.documentID(for: afterMidnight, calendar: calendar), "2026-03-08")
        XCTAssertEqual(start.duration, 23 * 60 * 60, accuracy: 0.01)
        XCTAssertFalse(WaterIntakeDay.contains(beforeMidnight, on: afterMidnight, calendar: calendar))
        XCTAssertTrue(WaterIntakeDay.contains(afterDaylightSavingTransition, on: afterMidnight, calendar: calendar))
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

    // MARK: - Meal Planning Calendar Tests

    func testPolishCalendarWeeksStartOnMondayAndContainSevenLocalDays() throws {
        let timezone = try XCTUnwrap(TimeZone(identifier: "Europe/Warsaw"))
        var base = Calendar(identifier: .gregorian)
        base.timeZone = timezone
        let polishCalendar = MealPlanningCalendar.configured(
            locale: Locale(identifier: "pl_PL"),
            base: base
        )
        let sunday = try fixedDate(2026, 3, 29, calendar: polishCalendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .week, containing: sunday, calendar: polishCalendar))
        let dates = MealPlanningCalendar.dates(in: range, calendar: polishCalendar)

        XCTAssertEqual(polishCalendar.firstWeekday, 2)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(polishCalendar.component(.weekday, from: dates.first!), 2)
        XCTAssertEqual(polishCalendar.component(.weekday, from: dates.last!), 1)
        XCTAssertEqual(range.lastDay(calendar: polishCalendar), dates.last)
        XCTAssertEqual(range.endDateExclusive.timeIntervalSince(range.startDate), 167 * 60 * 60, accuracy: 1)
    }

    func testMealCalendarMonthBoundariesLeapYearsAndClampedNavigation() throws {
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let february = try fixedDate(2024, 2, 14, calendar: calendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .month, containing: february, calendar: calendar))
        XCTAssertEqual(MealPlanningCalendar.dates(in: range, calendar: calendar).count, 29)
        XCTAssertEqual(calendar.component(.day, from: range.lastDay(calendar: calendar)), 29)

        let january31 = try fixedDate(2024, 1, 31, calendar: calendar)
        let february29 = try XCTUnwrap(MealPlanningCalendar.monthDate(byAdding: 1, to: january31, calendar: calendar))
        XCTAssertEqual(calendar.component(.month, from: february29), 2)
        XCTAssertEqual(calendar.component(.day, from: february29), 29)
    }

    func testMealEntriesAreFilteredByInclusiveLocalCalendarPeriod() throws {
        let timezone = try XCTUnwrap(TimeZone(identifier: "Europe/Warsaw"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = 2
        let anchor = try fixedDate(2026, 3, 29, calendar: calendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .week, containing: anchor, calendar: calendar))
        let monday = try fixedDate(2026, 3, 23, calendar: calendar)
        let nextMonday = try fixedDate(2026, 3, 30, calendar: calendar)
        let inside = makePlannedMeal(id: "inside", recipeID: "recipe", date: monday)
        let lastDayLate = try fixedLocalTime(on: range.lastDay(calendar: calendar), hour: 23, minute: 59, calendar: calendar)
        let sunday = makePlannedMeal(id: "last-day", recipeID: "recipe", date: lastDayLate)
        let outside = makePlannedMeal(id: "outside", recipeID: "recipe", date: nextMonday)

        let result = MealPlanningCalendar.entries([inside, sunday, outside], in: range, calendar: calendar)
        XCTAssertEqual(Set(result.compactMap(\.id)), ["inside", "last-day"])
    }

    func testMealPlanEntryValidationAndIndependentEditValues() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var first = makePlannedMeal(id: "one", recipeID: "recipe-a", date: date, servings: 2)
        let second = makePlannedMeal(id: "two", recipeID: "recipe-a", date: date, servings: 1)
        try MealPlannerManager.validate(entry: first, authenticatedUserID: "test-user")
        try MealPlannerManager.validate(entry: second, authenticatedUserID: "test-user")

        first.date = date.addingTimeInterval(86_400)
        first.mealType = "dinner"
        first.plannedServings = 4

        XCTAssertEqual(first.id, "one")
        XCTAssertEqual(first.plannedServings, 4)
        XCTAssertEqual(second.plannedServings, 1)
        XCTAssertEqual(second.date, date)
        XCTAssertThrowsError(try MealPlannerManager.validate(entry: first, authenticatedUserID: "another-user"))
        first.plannedServings = 0
        XCTAssertThrowsError(try MealPlannerManager.validate(entry: first, authenticatedUserID: "test-user"))
    }

    // MARK: - Shopping List Ingredient Aggregation Tests

    func testShoppingListCombinesNameFormattingAndAddsGramAmounts() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = [
            makeMealRecipe(id: "a", name: "Recipe A", servings: 2, ingredients: [Ingredient(name: " Flour ", quantity: 200, unit: "g")]),
            makeMealRecipe(id: "b", name: "Recipe B", servings: 2, ingredients: [Ingredient(name: "flour", quantity: 300, unit: "grams")])
        ]
        let entries = [
            makePlannedMeal(id: "meal-a", recipeID: "a", date: date, servings: 2),
            makePlannedMeal(id: "meal-b", recipeID: "b", date: date, servings: 2)
        ]

        let items = ShoppingListGenerator.generate(from: entries, recipes: recipes)
        let flour = try XCTUnwrap(items.first { $0.name.localizedCaseInsensitiveContains("flour") })
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(flour.quantity, 500, accuracy: 0.000_001)
        XCTAssertEqual(flour.unit, "g")
        XCTAssertEqual(Set(flour.sourceRecipeIDs ?? []), ["a", "b"])
    }

    func testShoppingListNormalizesMassVolumeAndCountUnits() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = [
            makeMealRecipe(id: "a", name: "A", servings: 1, ingredients: [
                Ingredient(name: "flour", quantity: 500, unit: "g"),
                Ingredient(name: "milk", quantity: 250, unit: "ml"),
                Ingredient(name: "egg", quantity: 2, unit: "pieces")
            ]),
            makeMealRecipe(id: "b", name: "B", servings: 1, ingredients: [
                Ingredient(name: " FLOUR ", quantity: 0.5, unit: "kg"),
                Ingredient(name: "Milk", quantity: 0.5, unit: "l"),
                Ingredient(name: "egg", quantity: 3, unit: "pcs")
            ])
        ]
        let entries = ["a", "b"].enumerated().map {
            makePlannedMeal(id: "meal-\($0.offset)", recipeID: $0.element, date: date)
        }
        let items = ShoppingListGenerator.generate(from: entries, recipes: recipes)

        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "flour" }).quantity, 1_000, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "flour" }).unit, "g")
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "milk" }).quantity, 750, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "milk" }).unit, "ml")
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "egg" }).quantity, 5, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name.lowercased() == "egg" }).unit, "piece")
    }

    func testShoppingListKeepsDifferentIngredientsAndDimensionsSeparate() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipe = makeMealRecipe(id: "a", name: "A", servings: 1, ingredients: [
            Ingredient(name: "wheat flour", quantity: 200, unit: "g"),
            Ingredient(name: "almond flour", quantity: 100, unit: "g"),
            Ingredient(name: "milk", quantity: 200, unit: "g"),
            Ingredient(name: "milk", quantity: 100, unit: "ml"),
            Ingredient(name: "fresh basil", quantity: 4, unit: "g"),
            Ingredient(name: "dried basil", quantity: 2, unit: "g")
        ])

        let items = ShoppingListGenerator.generate(
            from: [makePlannedMeal(id: "meal", recipeID: "a", date: date)],
            recipes: [recipe]
        )
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.filter { $0.name == "milk" }.count, 2)
        XCTAssertEqual(items.filter { $0.name.contains("flour") }.count, 2)
    }

    func testShoppingListScalesPlannedServingsBeforeAggregationAcrossRecipes() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = [
            makeMealRecipe(id: "a", name: "A", servings: 2, ingredients: [Ingredient(name: "rice", quantity: 200, unit: "g")]),
            makeMealRecipe(id: "b", name: "B", servings: 4, ingredients: [Ingredient(name: "rice", quantity: 200, unit: "g")])
        ]
        let entries = [
            makePlannedMeal(id: "meal-a", recipeID: "a", date: date, servings: 4),
            makePlannedMeal(id: "meal-b", recipeID: "b", date: date, servings: 2)
        ]
        let rice = try XCTUnwrap(ShoppingListGenerator.generate(from: entries, recipes: recipes).first)
        XCTAssertEqual(rice.quantity, 500, accuracy: 0.000_001)
    }

    func testRepeatedRecipeAssignmentsAreCountedIndependently() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipe = makeMealRecipe(id: "a", name: "A", servings: 2, ingredients: [Ingredient(name: "oats", quantity: 100, unit: "g")])
        let entries = [
            makePlannedMeal(id: "meal-1", recipeID: "a", date: date, servings: 2),
            makePlannedMeal(id: "meal-2", recipeID: "a", date: date, servings: 4)
        ]
        let oats = try XCTUnwrap(ShoppingListGenerator.generate(from: entries, recipes: [recipe]).first)
        XCTAssertEqual(oats.quantity, 300, accuracy: 0.000_001)
        XCTAssertEqual(Set(oats.sourceMealEntryIDs ?? []), ["meal-1", "meal-2"])
    }

    func testShoppingListUsesSectionIngredientsWithoutDoubleCountingFlatCopy() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var recipe = makeMealRecipe(
            id: "sectioned",
            name: "Layered recipe",
            servings: 2,
            ingredients: [Ingredient(name: "flour", quantity: 200, unit: "g")]
        )
        recipe.sections = [
            RecipeSection(
                title: "Dough",
                ingredients: [
                    Ingredient(name: "flour", quantity: 200, unit: "g"),
                    Ingredient(name: "salt", quantity: 3, unit: "g")
                ],
                instructions: []
            )
        ]

        let items = ShoppingListGenerator.generate(
            from: [makePlannedMeal(id: "meal", recipeID: "sectioned", date: date, servings: 2)],
            recipes: [recipe]
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name == "flour" }).quantity, 200, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(items.first { $0.name == "salt" }).quantity, 3, accuracy: 0.000_001)
    }

    func testShoppingListPreservesUnquantifiedInvalidAndUnscaledIngredients() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = [
            makeMealRecipe(id: "unknown-servings", name: "Legacy", servings: 0, ingredients: [Ingredient(name: "flour", quantity: 200, unit: "g")]),
            makeMealRecipe(id: "unknown-amount", name: "Taste", servings: 2, ingredients: [Ingredient(name: "salt", quantity: 0, unit: "to taste")]),
            makeMealRecipe(id: "invalid", name: "Invalid", servings: 2, ingredients: [Ingredient(name: "pepper", quantity: .nan, unit: "g")]),
            makeMealRecipe(id: "unitless", name: "Unitless", servings: 2, ingredients: [Ingredient(name: "spice", quantity: 3, unit: "")])
        ]
        let entries = recipes.map { recipe in
            makePlannedMeal(id: "meal-\(recipe.id!)", recipeID: recipe.id!, date: date, servings: 4)
        }
        let items = ShoppingListGenerator.generate(from: entries, recipes: recipes)

        let flour = try XCTUnwrap(items.first { $0.name == "flour" })
        XCTAssertEqual(flour.quantity, 200, accuracy: 0.000_001)
        XCTAssertNotNil(flour.quantityNote)
        XCTAssertEqual(items.first { $0.name == "salt" }?.unit, "to taste")
        XCTAssertEqual(items.first { $0.name == "pepper" }?.quantity, 0)
        let spice = try XCTUnwrap(items.first { $0.name == "spice" })
        XCTAssertEqual(spice.quantity, 6, accuracy: 0.000_001)
        XCTAssertTrue(spice.unit.isEmpty)
        XCTAssertNotNil(spice.generationKey)
    }

    func testShoppingListPeriodExcludesRecipesOutsideLocalDateRange() throws {
        let timezone = try XCTUnwrap(TimeZone(identifier: "Europe/Warsaw"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let monday = try fixedDate(2026, 10, 26, calendar: calendar)
        let nextMonday = try fixedDate(2026, 11, 2, calendar: calendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .week, containing: monday, calendar: calendar))
        let recipes = [
            makeMealRecipe(id: "inside", name: "Inside", servings: 1, ingredients: [Ingredient(name: "pear", quantity: 2, unit: "piece")]),
            makeMealRecipe(id: "outside", name: "Outside", servings: 1, ingredients: [Ingredient(name: "plum", quantity: 3, unit: "piece")])
        ]
        let lastDayDate = try fixedLocalTime(on: range.lastDay(calendar: calendar), hour: 23, minute: 59, calendar: calendar)
        let lastDay = makePlannedMeal(id: "last", recipeID: "inside", date: lastDayDate)
        let outside = makePlannedMeal(id: "outside", recipeID: "outside", date: nextMonday)
        let items = ShoppingListGenerator.generate(from: [lastDay, outside], recipes: recipes, within: range, calendar: calendar)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "pear")
    }

    func testMealPlanPeriodGenerationIntegratesScalingAggregationAndRecipeRefresh() throws {
        let suiteName = "ShoppingListWorkflowTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let timezone = try XCTUnwrap(TimeZone(identifier: "Europe/Warsaw"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = 2

        let monday = try fixedDate(2026, 10, 26, calendar: calendar)
        let nextMonday = try fixedDate(2026, 11, 2, calendar: calendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .week, containing: monday, calendar: calendar))
        let firstRecipe = makeMealRecipe(
            id: "first",
            name: "Bread",
            servings: 2,
            ingredients: [Ingredient(name: "flour", quantity: 200, unit: "g")]
        )
        let secondRecipe = makeMealRecipe(
            id: "second",
            name: "Pancakes",
            servings: 5,
            ingredients: [Ingredient(name: " Flour ", quantity: 0.5, unit: "kg")]
        )
        let outsideRecipe = makeMealRecipe(
            id: "outside",
            name: "Soup",
            servings: 1,
            ingredients: [Ingredient(name: "salt", quantity: 10, unit: "g")]
        )
        let firstEntry = makePlannedMeal(id: "meal-first", recipeID: "first", date: monday, servings: 4)
        let secondEntry = makePlannedMeal(id: "meal-second", recipeID: "second", date: monday.addingTimeInterval(86_400), servings: 5)
        let outsideEntry = makePlannedMeal(id: "meal-outside", recipeID: "outside", date: nextMonday)
        let manager = ShoppingListManager(defaults: defaults, userID: "workflow-user")

        manager.regenerate(
            from: [firstEntry, secondEntry, outsideEntry],
            recipes: [firstRecipe, secondRecipe, outsideRecipe],
            within: range,
            calendar: calendar
        )
        var flour = try XCTUnwrap(manager.shoppingList.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == "flour" })
        XCTAssertEqual(flour.quantity, 900, accuracy: 0.000_001)
        XCTAssertEqual(flour.unit, "g")
        XCTAssertEqual(Set(flour.sourceMealEntryIDs ?? []), ["meal-first", "meal-second"])
        XCTAssertFalse(manager.shoppingList.contains(where: { $0.name == "salt" }))

        manager.toggleCompletion(flour)
        var updatedFirstRecipe = firstRecipe
        updatedFirstRecipe.ingredients = [Ingredient(name: "flour", quantity: 300, unit: "g")]
        manager.regenerate(
            from: [firstEntry, secondEntry, outsideEntry],
            recipes: [updatedFirstRecipe, secondRecipe, outsideRecipe],
            within: range,
            calendar: calendar
        )
        flour = try XCTUnwrap(manager.shoppingList.first { $0.name.lowercased() == "flour" })
        XCTAssertEqual(flour.quantity, 1_100, accuracy: 0.000_001)
        XCTAssertTrue(flour.isCompleted)

        var movedSecondEntry = secondEntry
        movedSecondEntry.date = nextMonday
        manager.regenerate(
            from: [firstEntry, movedSecondEntry, outsideEntry],
            recipes: [updatedFirstRecipe, secondRecipe, outsideRecipe],
            within: range,
            calendar: calendar
        )
        flour = try XCTUnwrap(manager.shoppingList.first { $0.name.lowercased() == "flour" })
        XCTAssertEqual(flour.quantity, 600, accuracy: 0.000_001)
        XCTAssertEqual(Set(flour.sourceMealEntryIDs ?? []), ["meal-first"])
        XCTAssertFalse(manager.shoppingList.contains(where: { $0.name == "salt" }))
    }

    func testShoppingListReconciliationPreservesEditsPurchaseCustomAndRemoval() throws {
        let suiteName = "ShoppingListTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let day = try fixedDate(2026, 10, 30, calendar: calendar)
        let range = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .day, containing: day, calendar: calendar))
        let recipe = makeMealRecipe(id: "recipe", name: "Soup", servings: 2, ingredients: [
            Ingredient(name: "carrot", quantity: 200, unit: "g"),
            Ingredient(name: "salt", quantity: 2, unit: "g")
        ])
        let entry = makePlannedMeal(id: "meal", recipeID: "recipe", date: day, servings: 2)
        let manager = ShoppingListManager(defaults: defaults, userID: "user-a")
        manager.regenerate(from: [entry], recipes: [recipe], within: range, calendar: calendar)

        var carrot = try XCTUnwrap(manager.shoppingList.first { $0.name == "carrot" })
        carrot.name = "Carrot, edited"
        carrot.quantity = 250
        carrot.isManuallyEdited = true
        manager.updateItem(carrot)
        let salt = try XCTUnwrap(manager.shoppingList.first { $0.name == "salt" })
        manager.toggleCompletion(salt)
        manager.deleteItem(carrot)
        manager.addItem(ShoppingListItem(name: "Coffee", quantity: 1, unit: "bag", isManuallyAdded: true))

        manager.regenerate(from: [entry], recipes: [recipe], within: range, calendar: calendar)
        XCTAssertTrue(manager.shoppingList.contains(where: { $0.isExcludedFromGeneration && $0.name == "Carrot, edited" }))
        XCTAssertTrue(manager.shoppingList.contains(where: { $0.name == "Coffee" && $0.isManuallyAdded }))
        XCTAssertTrue(manager.shoppingList.contains(where: { $0.name == "salt" && $0.isCompleted }))
        XCTAssertFalse(manager.shoppingList.contains(where: { $0.name == "carrot" && !$0.isExcludedFromGeneration }))

        let restored = ShoppingListManager(defaults: defaults, userID: "user-a")
        XCTAssertEqual(restored.shoppingList, manager.shoppingList)
        let otherUser = ShoppingListManager(defaults: defaults, userID: "user-b")
        XCTAssertTrue(otherUser.shoppingList.isEmpty)
    }

    func testShoppingListChangesPeriodWithoutReintroducingCustomItems() throws {
        let suiteName = "ShoppingListPeriodTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = waterTestCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let firstDay = try fixedDate(2026, 10, 30, calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let dayRange = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .day, containing: firstDay, calendar: calendar))
        let nextRange = try XCTUnwrap(MealPlanningCalendar.dateRange(for: .day, containing: nextDay, calendar: calendar))
        let recipe = makeMealRecipe(id: "recipe", name: "Pasta", servings: 1, ingredients: [Ingredient(name: "pasta", quantity: 100, unit: "g")])
        let entry = makePlannedMeal(id: "meal", recipeID: "recipe", date: firstDay)
        let manager = ShoppingListManager(defaults: defaults, userID: "user")
        manager.regenerate(from: [entry], recipes: [recipe], within: dayRange, calendar: calendar)
        manager.deleteItem(try XCTUnwrap(manager.shoppingList.first { $0.name == "pasta" }))
        manager.addItem(ShoppingListItem(name: "Tea", quantity: 0, unit: "", isManuallyAdded: true))

        manager.regenerate(from: [entry], recipes: [recipe], within: nextRange, calendar: calendar)
        XCTAssertFalse(manager.shoppingList.contains(where: { $0.name == "pasta" }))
        XCTAssertTrue(manager.shoppingList.contains(where: { $0.name == "Tea" }))
        XCTAssertFalse(manager.shoppingList.contains(where: \.isExcludedFromGeneration))
    }

    func testLegacyShoppingListItemsDecodeWithNewOptionalMetadata() throws {
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","name":"Old item","quantity":2,"unit":"piece","isCompleted":true,"isManuallyAdded":false,"recipeSources":["Old recipe"]}]
        """.data(using: .utf8)!
        let item = try XCTUnwrap(JSONDecoder().decode([ShoppingListItem].self, from: json).first)
        XCTAssertEqual(item.name, "Old item")
        XCTAssertTrue(item.isCompleted)
        XCTAssertFalse(item.isManuallyEdited)
        XCTAssertFalse(item.isExcludedFromGeneration)
        XCTAssertNil(item.generationKey)
    }

    private func makeMealRecipe(id: String, name: String, servings: Int, ingredients: [Ingredient]) -> Recipe {
        Recipe(
            id: id,
            userId: "test-user",
            name: name,
            category: "BASICS",
            preparationTimeMinutes: 10,
            servings: servings,
            ingredients: ingredients,
            instructions: []
        )
    }

    private func makePlannedMeal(
        id: String,
        recipeID: String,
        date: Date,
        servings: Int = 1,
        mealType: String = "breakfast"
    ) -> MealPlanEntry {
        var entry = MealPlanEntry(
            userId: "test-user",
            date: date,
            mealType: mealType,
            recipeId: recipeID,
            recipeName: recipeID,
            plannedServings: servings
        )
        entry.id = id
        entry.date = date
        return entry
    }

    private func fixedDate(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func fixedLocalTime(on date: Date, hour: Int, minute: Int, calendar: Calendar) throws -> Date {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return try XCTUnwrap(calendar.date(from: components))
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

    private func makeWaterRecord(documentID: String, entries: [WaterEntry]) -> WaterRecord {
        var record = WaterRecord.empty(userId: "water-test-user")
        record.id = documentID
        record.entries = entries
        return record
    }

    private func waterTestCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func waterTestDate(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: value)
        return try XCTUnwrap(date, "Invalid fixed water-tracker test date: \(value)")
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
