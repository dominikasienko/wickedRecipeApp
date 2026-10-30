//
//  UserProfile.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import FirebaseFirestore
import Foundation
import SwiftUI

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    
    let userId: String
    
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var weight: Double
    /// Optional clinician- or dietitian-provided reference weight for the fluid estimate.
    var referenceWeightKg: Double? = nil
    var height: Double
    var gender: String
    var activityLevel: String
    var selectedDiets: [String]
    var weightGoal: String? = nil
    var profileImageURL: String?
    var canUseGeneralEstimates: Bool? = nil
    var ageEligibilityConfirmedAt: Date? = nil
    var healthDataConsentAt: Date? = nil
    var privacyPolicyVersion: String? = nil
    
// MARK: - CodingKeys do Mapowania Firestore
    enum CodingKeys: String, CodingKey {
        case userId = "uid"
        case firstName, lastName, dateOfBirth, weight, referenceWeightKg, height, gender, activityLevel, selectedDiets, weightGoal, profileImageURL
        case canUseGeneralEstimates
        case ageEligibilityConfirmedAt, healthDataConsentAt, privacyPolicyVersion
    }

    static func empty(userId: String) -> UserProfile {
        UserProfile(
            userId: userId,
            firstName: "New",
            lastName: "User",
            dateOfBirth: Date(),
            weight: 70.0,
            height: 175.0,
            gender: "other",
            activityLevel: "",
            selectedDiets: [],
            weightGoal: nil,
            canUseGeneralEstimates: false
        )
    }
    
    var age: Int {
        AgeEligibility.age(on: dateOfBirth)
    }

    var localizedGender: LocalizedStringKey {
        AppOptionCatalog.localizedTitle(for: gender, in: AppOptionCatalog.genders)
    }

    var localizedActivityLevel: LocalizedStringKey {
        AppOptionCatalog.localizedTitle(for: activityLevel, in: AppOptionCatalog.activityLevels)
    }

    var localizedWeightGoal: LocalizedStringKey {
        guard let weightGoal, !weightGoal.isEmpty else { return AppLocalization.key("Not set") }
        return AppOptionCatalog.localizedTitle(for: weightGoal, in: AppOptionCatalog.weightGoals)
    }

    var dietLocalizationKeys: [String] {
        selectedDiets.map {
            AppOptionCatalog.localizationKey(for: $0, in: AppOptionCatalog.dietOptions) ?? $0
        }
    }

    func canonicalizedForStorage() -> UserProfile {
        var profile = self
        profile.gender = AppOptionCatalog.canonicalValue(for: gender, in: AppOptionCatalog.genders)
        profile.activityLevel = AppOptionCatalog.canonicalValue(for: activityLevel, in: AppOptionCatalog.activityLevels)
        profile.selectedDiets = selectedDiets.map {
            AppOptionCatalog.canonicalValue(for: $0, in: AppOptionCatalog.dietOptions)
        }
        profile.weightGoal = weightGoal.map {
            AppOptionCatalog.canonicalValue(for: $0, in: AppOptionCatalog.weightGoals)
        }
        return profile
    }
    
    var isHealthProfileComplete: Bool {
        let hasValidWeight = HydrationCalculationService.supportedWeightRangeKg.contains(weight)
        let hasValidHeight = HydrationCalculationService.supportedHeightRangeCm.contains(height)
        let hasValidAge = (AgeEligibility.minimumAge...AgeEligibility.maximumAge).contains(age)
        let hasSupportedSex = resolvedSexCategory != nil
        let hasActivity = resolvedActivityCategory != nil

        return hasCurrentHealthConsent
            && canUseGeneralEstimates == true
            && hasValidWeight
            && hasValidHeight
            && hasValidAge
            && hasSupportedSex
            && hasActivity
    }

    private var hasCurrentHealthConsent: Bool {
        ageEligibilityConfirmedAt != nil
            && healthDataConsentAt != nil
            && privacyPolicyVersion == LegalLinks.privacyPolicyVersion
    }
    
    private var resolvedActivityCategory: String? {
        let category = AppOptionCatalog.canonicalValue(for: activityLevel, in: AppOptionCatalog.activityLevels)
        return ["inactive", "lowActive", "active", "veryActive"].contains(category) ? category : nil
    }

    private var resolvedSexCategory: String? {
        let category = AppOptionCatalog.canonicalValue(for: gender, in: AppOptionCatalog.genders)
        return ["man", "woman"].contains(category) ? category : nil
    }

    /// NASEM 2023 Estimated Energy Requirement for weight maintenance.
    /// The equations use age in years, weight in kg, height in cm, and a
    /// population-level PAL category; they are not a weight-loss prescription.
    func calculateEstimatedEnergyRequirementKcal() -> Double? {
        guard isHealthProfileComplete,
              let sex = resolvedSexCategory,
              let activity = resolvedActivityCategory else { return nil }

        let a = Double(age)
        let h = height
        let w = weight
        let estimate: Double

        if age < 19 {
            switch (sex, activity) {
            case ("man", "inactive"):
                estimate = -447.51 + 3.68 * a + 13.01 * h + 13.15 * w + 20
            case ("man", "lowActive"):
                estimate = 19.12 + 3.68 * a + 8.62 * h + 20.28 * w + 20
            case ("man", "active"):
                estimate = -388.19 + 3.68 * a + 12.66 * h + 20.46 * w + 20
            case ("man", "veryActive"):
                estimate = -671.75 + 3.68 * a + 15.38 * h + 23.25 * w + 20
            case ("woman", "inactive"):
                estimate = 55.59 - 22.25 * a + 8.43 * h + 17.07 * w + 20
            case ("woman", "lowActive"):
                estimate = -297.54 - 22.25 * a + 12.77 * h + 14.73 * w + 20
            case ("woman", "active"):
                estimate = -189.55 - 22.25 * a + 11.74 * h + 18.34 * w + 20
            case ("woman", "veryActive"):
                estimate = -709.59 - 22.25 * a + 18.22 * h + 14.25 * w + 20
            default:
                return nil
            }
        } else {
            switch (sex, activity) {
            case ("man", "inactive"):
                estimate = 753.07 - 10.83 * a + 6.50 * h + 14.10 * w
            case ("man", "lowActive"):
                estimate = 581.47 - 10.83 * a + 8.30 * h + 14.94 * w
            case ("man", "active"):
                estimate = 1004.82 - 10.83 * a + 6.52 * h + 15.91 * w
            case ("man", "veryActive"):
                estimate = -517.88 - 10.83 * a + 15.61 * h + 19.11 * w
            case ("woman", "inactive"):
                estimate = 584.90 - 7.01 * a + 5.72 * h + 11.71 * w
            case ("woman", "lowActive"):
                estimate = 575.77 - 7.01 * a + 6.60 * h + 12.14 * w
            case ("woman", "active"):
                estimate = 710.25 - 7.01 * a + 6.54 * h + 12.34 * w
            case ("woman", "veryActive"):
                estimate = 511.83 - 7.01 * a + 9.07 * h + 12.56 * w
            default:
                return nil
            }
        }

        guard estimate.isFinite, estimate > 0 else { return nil }
        return estimate
    }

    func hydrationAssessment(lifeStage: HydrationLifeStage = .standard) -> HydrationAssessment? {
        let referenceSex: HydrationReferenceSex?
        switch resolvedSexCategory {
        case "woman": referenceSex = .female
        case "man": referenceSex = .male
        default: referenceSex = nil
        }

        return HydrationCalculationService.assess(
            HydrationProfileInput(
                age: age,
                referenceSex: referenceSex,
                currentWeightKg: weight,
                heightCm: height,
                providedReferenceWeightKg: referenceWeightKg,
                lifeStage: lifeStage,
                isEligibleForGeneralEstimates: hasCurrentHealthConsent && canUseGeneralEstimates == true
            )
        )
    }

    struct NutrientRange {
        let lowerGrams: Double
        let upperGrams: Double
    }

    struct Macros {
        let proteinG: NutrientRange
        let fatG: NutrientRange
        let carbsG: NutrientRange
        let totalCalories: Int
    }

    func calculateMacrosIfProfileComplete() -> Macros? {
        guard let energy = calculateEstimatedEnergyRequirementKcal() else { return nil }

        let proteinPercent = age < 19 ? (10.0...30.0) : (10.0...35.0)
        let fatPercent = age < 19 ? (25.0...35.0) : (20.0...35.0)
        let carbohydratePercent = 45.0...65.0

        func grams(_ percentage: Double, caloriesPerGram: Double) -> Double {
            energy * percentage / 100 / caloriesPerGram
        }

        return Macros(
            proteinG: NutrientRange(
                lowerGrams: grams(proteinPercent.lowerBound, caloriesPerGram: 4),
                upperGrams: grams(proteinPercent.upperBound, caloriesPerGram: 4)
            ),
            fatG: NutrientRange(
                lowerGrams: grams(fatPercent.lowerBound, caloriesPerGram: 9),
                upperGrams: grams(fatPercent.upperBound, caloriesPerGram: 9)
            ),
            carbsG: NutrientRange(
                lowerGrams: grams(carbohydratePercent.lowerBound, caloriesPerGram: 4),
                upperGrams: grams(carbohydratePercent.upperBound, caloriesPerGram: 4)
            ),
            totalCalories: Int(energy.rounded())
        )
    }
}

enum ProfileImageEditState: Equatable {
    case unchanged
    case replacement
    case removal

    func applying(to profile: UserProfile, replacementURL: String? = nil) -> UserProfile? {
        var updatedProfile = profile
        switch self {
        case .unchanged:
            return updatedProfile
        case .replacement:
            guard let replacementURL, !replacementURL.isEmpty else { return nil }
            updatedProfile.profileImageURL = replacementURL
        case .removal:
            updatedProfile.profileImageURL = nil
        }
        return updatedProfile
    }
}
