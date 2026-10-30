import Foundation

enum HydrationReferenceSex: Equatable {
    case female
    case male
}

/// EFSA life-stage adjustments are available to the calculation service, but the current
/// profile does not collect or persist pregnancy or lactation status.
enum HydrationLifeStage: Equatable {
    case standard
    case pregnancy
    case lactation
}

enum FluidEstimateWeightSource: Equatable {
    case currentBodyWeight
    case providedReferenceWeight
}

enum FluidEstimateUnavailableReason: Equatable {
    case adultEstimateOnly
    case validHeightAndWeightRequired
    case referenceWeightRequiredForBMI25OrHigher
    case validReferenceWeightRequired
}

struct EFSAWaterReference: Equatable {
    let totalWaterMlPerDay: Double
    let lifeStage: HydrationLifeStage
}

struct DailyFluidEstimate: Equatable {
    let estimatedMlPerDay: Double
    let weightKgUsed: Double
    let weightSource: FluidEstimateWeightSource
}

struct HydrationAssessment: Equatable {
    let efsaReference: EFSAWaterReference?
    let dailyFluidEstimate: DailyFluidEstimate?
    let fluidEstimateUnavailableReason: FluidEstimateUnavailableReason?
}

struct HydrationProfileInput {
    let age: Int
    let referenceSex: HydrationReferenceSex?
    let currentWeightKg: Double
    let heightCm: Double
    /// A reference weight entered by the user after receiving clinical guidance.
    let providedReferenceWeightKg: Double?
    let lifeStage: HydrationLifeStage
    let isEligibleForGeneralEstimates: Bool
}

enum HydrationCalculationService {
    static let supportedWeightRangeKg: ClosedRange<Double> = 30...300
    static let supportedHeightRangeCm: ClosedRange<Double> = 120...250
    static let adultMinimumAge = 18
    static let adultFemaleEFSAReferenceMl = 2_000.0
    static let adultMaleEFSAReferenceMl = 2_500.0
    static let pregnancyAdditionalEFSAWaterMl = 300.0
    static let lactationAdditionalEFSAWaterMl = 700.0
    static let fluidEstimateMlPerKg = 30.0
    static let adultBMIOverweightThreshold = 25.0

    static func assess(_ input: HydrationProfileInput) -> HydrationAssessment? {
        guard input.isEligibleForGeneralEstimates,
              (AgeEligibility.minimumAge...AgeEligibility.maximumAge).contains(input.age) else { return nil }

        let reference = efsaReference(
            sex: input.referenceSex,
            lifeStage: input.lifeStage
        )
        let estimateResult = dailyFluidEstimate(
            age: input.age,
            currentWeightKg: input.currentWeightKg,
            heightCm: input.heightCm,
            providedReferenceWeightKg: input.providedReferenceWeightKg
        )

        return HydrationAssessment(
            efsaReference: reference,
            dailyFluidEstimate: estimateResult.estimate,
            fluidEstimateUnavailableReason: estimateResult.reason
        )
    }

    static func efsaReference(
        sex: HydrationReferenceSex?,
        lifeStage: HydrationLifeStage = .standard
    ) -> EFSAWaterReference? {
        guard let sex else { return nil }
        guard lifeStage == .standard || sex == .female else { return nil }

        let base: Double
        switch sex {
        case .female: base = adultFemaleEFSAReferenceMl
        case .male: base = adultMaleEFSAReferenceMl
        }

        let adjustment: Double
        switch (sex, lifeStage) {
        case (.female, .pregnancy): adjustment = pregnancyAdditionalEFSAWaterMl
        case (.female, .lactation): adjustment = lactationAdditionalEFSAWaterMl
        default: adjustment = 0
        }

        return EFSAWaterReference(totalWaterMlPerDay: base + adjustment, lifeStage: lifeStage)
    }

    private static func dailyFluidEstimate(
        age: Int,
        currentWeightKg: Double,
        heightCm: Double,
        providedReferenceWeightKg: Double?
    ) -> (estimate: DailyFluidEstimate?, reason: FluidEstimateUnavailableReason?) {
        guard age >= adultMinimumAge else { return (nil, .adultEstimateOnly) }
        guard isValid(currentWeightKg, in: supportedWeightRangeKg),
              isValid(heightCm, in: supportedHeightRangeCm) else {
            return (nil, .validHeightAndWeightRequired)
        }

        let heightM = heightCm / 100
        let bmi = currentWeightKg / (heightM * heightM)
        let weightToUse: Double
        let source: FluidEstimateWeightSource

        if bmi < adultBMIOverweightThreshold {
            weightToUse = currentWeightKg
            source = .currentBodyWeight
        } else {
            guard let referenceWeight = providedReferenceWeightKg else {
                return (nil, .referenceWeightRequiredForBMI25OrHigher)
            }
            guard isValid(referenceWeight, in: supportedWeightRangeKg), referenceWeight < currentWeightKg else {
                return (nil, .validReferenceWeightRequired)
            }
            weightToUse = referenceWeight
                source = .providedReferenceWeight
        }

        return (
            DailyFluidEstimate(
                // NCEŻ's practical lower estimate is weight in kg × 30 ml; it is not an EFSA equation.
                estimatedMlPerDay: weightToUse * fluidEstimateMlPerKg,
                weightKgUsed: weightToUse,
                weightSource: source
            ),
            nil
        )
    }

    private static func isValid(_ value: Double, in range: ClosedRange<Double>) -> Bool {
        value.isFinite && range.contains(value)
    }
}

struct ExerciseHydrationInput: Equatable {
    let preExerciseWeightKg: Double
    let postExerciseWeightKg: Double
    let durationMinutes: Double
    let fluidConsumedMl: Double
    let urineOutputMl: Double
}

struct ExerciseHydrationEstimate: Equatable {
    let input: ExerciseHydrationInput
    let estimatedSweatLossLiters: Double
    let estimatedSweatRateLitersPerHour: Double
    let bodyMassLossLiters: Double
    let recoveryFluidRangeMl: ClosedRange<Double>?
}

enum ExerciseHydrationCalculator {
    static let bodyMassLossReplacementRange = 1.0...1.2
    static let millilitersPerLiter = 1_000.0
    static let minutesPerHour = 60.0

    static func estimate(from input: ExerciseHydrationInput) -> ExerciseHydrationEstimate? {
        let values = [
            input.preExerciseWeightKg,
            input.postExerciseWeightKg,
            input.durationMinutes,
            input.fluidConsumedMl,
            input.urineOutputMl
        ]
        guard values.allSatisfy(\.isFinite),
              HydrationCalculationService.supportedWeightRangeKg.contains(input.preExerciseWeightKg),
              HydrationCalculationService.supportedWeightRangeKg.contains(input.postExerciseWeightKg),
              input.durationMinutes > 0,
              input.fluidConsumedMl >= 0,
              input.urineOutputMl >= 0 else { return nil }

        // The measured change in kg is used as an approximate equivalent of liters of water.
        let bodyMassLossLiters = input.preExerciseWeightKg - input.postExerciseWeightKg
        let estimatedSweatLossLiters = bodyMassLossLiters
            + input.fluidConsumedMl / millilitersPerLiter
            - input.urineOutputMl / millilitersPerLiter
        guard estimatedSweatLossLiters.isFinite, estimatedSweatLossLiters > 0 else { return nil }

        let durationHours = input.durationMinutes / minutesPerHour
        let sweatRate = estimatedSweatLossLiters / durationHours
        guard sweatRate.isFinite, sweatRate > 0 else { return nil }

        let recoveryRange: ClosedRange<Double>?
        if bodyMassLossLiters > 0 {
            recoveryRange = (bodyMassLossLiters * bodyMassLossReplacementRange.lowerBound * millilitersPerLiter)
                ... (bodyMassLossLiters * bodyMassLossReplacementRange.upperBound * millilitersPerLiter)
        } else {
            recoveryRange = nil
        }

        return ExerciseHydrationEstimate(
            input: input,
            estimatedSweatLossLiters: estimatedSweatLossLiters,
            estimatedSweatRateLitersPerHour: sweatRate,
            bodyMassLossLiters: max(bodyMassLossLiters, 0),
            recoveryFluidRangeMl: recoveryRange
        )
    }
}
