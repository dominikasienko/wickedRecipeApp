import SwiftUI

struct ExerciseHydrationCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preExerciseWeight = ""
    @State private var postExerciseWeight = ""
    @State private var durationMinutes = ""
    @State private var fluidConsumedMl = "0"
    @State private var urineOutputMl = "0"
    @State private var estimate: ExerciseHydrationEstimate?
    @State private var showingInputError = false

    private var parsedInput: ExerciseHydrationInput? {
        guard let before = ProfileMeasurementInput.parse(preExerciseWeight),
              let after = ProfileMeasurementInput.parse(postExerciseWeight),
              let duration = ProfileMeasurementInput.parse(durationMinutes),
              let fluid = ProfileMeasurementInput.parse(fluidConsumedMl),
              let urine = ProfileMeasurementInput.parse(urineOutputMl) else { return nil }
        return ExerciseHydrationInput(
            preExerciseWeightKg: before,
            postExerciseWeightKg: after,
            durationMinutes: duration,
            fluidConsumedMl: fluid,
            urineOutputMl: urine
        )
    }

    private var visibleEstimate: ExerciseHydrationEstimate? {
        guard let estimate, estimate.input == parsedInput else { return nil }
        return estimate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppLocalization.key("Measure one exercise session to estimate sweat loss and sweat rate. The result describes that session only and does not change your everyday fluid estimate."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))

                    inputField("Pre-exercise weight (kg)", text: $preExerciseWeight, id: "exercise.preWeight")
                    inputField("Post-exercise weight (kg)", text: $postExerciseWeight, id: "exercise.postWeight")
                    inputField("Exercise duration (minutes)", text: $durationMinutes, id: "exercise.duration")
                    inputField("Fluid consumed during exercise (ml)", text: $fluidConsumedMl, id: "exercise.fluid")
                    inputField("Urine output during exercise (ml; enter 0 if none)", text: $urineOutputMl, id: "exercise.urine")

                    if showingInputError {
                        Text(AppLocalization.key("Enter valid weights, a duration above zero, and non-negative fluid and urine amounts."))
                            .font(.footnote)
                            .foregroundStyle(Color.glindaPink)
                    }

                    Button(action: calculate) {
                        Text(AppLocalization.key("Calculate session estimate"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.wickedGreen)

                    if let visibleEstimate {
                        results(visibleEstimate)
                    }

                    Text(AppLocalization.key("Sweat rate varies with duration, intensity, temperature, humidity, clothing and individual physiology. This calculator does not collect environmental conditions, so do not generalize one session to other conditions."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))

                    Text(AppLocalization.key("The calculation treats about 1 kg of body-mass change as 1 L of water. Other body-mass changes and measurement error can affect the estimate. Avoid rapidly drinking large volumes; follow clinical advice for medical fluid needs."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))

                    Link(AppLocalization.key("IOC exercise and heat hydration consensus"), destination: URL(string: "https://bjsm.bmj.com/content/57/1/8")!)
                        .font(.caption)
                        .tint(.wickedGreen)
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle(AppLocalization.key("Exercise recovery estimate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.key("Done")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func inputField(_ title: LocalizedStringKey, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier(id)
        }
    }

    @ViewBuilder
    private func results(_ result: ExerciseHydrationEstimate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.key("Measured session estimate"))
                .font(.headline)
                .foregroundStyle(Color.wickedGreen)

            valueRow("Estimated sweat loss", value: "\(result.estimatedSweatLossLiters.formatted(.number.precision(.fractionLength(2)))) L")
            valueRow("Estimated sweat rate", value: "\(result.estimatedSweatRateLitersPerHour.formatted(.number.precision(.fractionLength(2)))) L/h")

            if let range = result.recoveryFluidRangeMl {
                valueRow(
                    "Possible recovery range when appropriate (100–120% of body-mass loss)",
                    value: "\(Int((range.lowerBound / 50).rounded() * 50))–\(Int((range.upperBound / 50).rounded() * 50)) ml"
                )
            } else {
                Text(AppLocalization.key("No net body-mass loss was measured, so no replacement amount is shown."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(AppLocalization.key("The IOC describes 100–120% of body-mass loss for appropriate recovery, especially after exercise in heat. Fluids and food can contribute. This range is not added to the daily estimate."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func valueRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(.white)
    }

    private func calculate() {
        guard let parsedInput,
              let result = ExerciseHydrationCalculator.estimate(from: parsedInput) else {
            estimate = nil
            showingInputError = true
            return
        }
        estimate = result
        showingInputError = false
    }
}
