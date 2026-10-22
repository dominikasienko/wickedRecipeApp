//
//  NutritionCalculationPanel.swift
//  RecipePlannerIOS
//
//  Created by Codex on 22/02/2026.
//

import SwiftUI

struct NutritionCalculationPanel: View {
    let result: NutritionCalculationResult?
    let isCalculating: Bool
    let infoMessage: LocalizedStringKey?
    var showCalculateButton: Bool = true
    var onCalculate: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showCalculateButton {
                Button(action: { onCalculate?() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "function")
                        Text(
                            isCalculating
                            ? AppLocalization.key( "Calculating...")
                            : AppLocalization.key( "Calculate Nutritional Values")
                        )
                        .fontWeight(.semibold)
                        Spacer()
                        if isCalculating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.wickedGreen.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.wickedGreen.opacity(0.85), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isCalculating || onCalculate == nil)
            }
            
            if let result {
                NutritionValuesCard(result: result)
            }
            
            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.glindaPink.opacity(0.95))
            }
        }
    }
}

private struct NutritionValuesCard: View {
    @Environment(\.locale) private var locale
    let result: NutritionCalculationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppLocalization.key( "Nutrition Per Serving"))
                    .font(.headline)
                    .foregroundStyle(Color.wickedGreen)
                Spacer()
                Text("Servings: \(result.servings)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Divider().overlay(Color.glindaPink.opacity(0.45))
            
            NutritionValueRow(title: "Calories", value: "\(Int(result.perServing.calories.rounded())) kcal")
            NutritionValueRow(title: "Carbohydrates", value: formatted(result.perServing.carbohydrates) + " g")
            NutritionValueRow(title: "Fat", value: formatted(result.perServing.fat) + " g")
            NutritionValueRow(title: "Protein", value: formatted(result.perServing.protein) + " g")
            
            Divider().overlay(Color.white.opacity(0.18))
            
            Text("Matched ingredients: \(result.matchedIngredients)/\(result.totalIngredients)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            
            if !result.missingIngredients.isEmpty {
                Text("No data for: \(compactMissingList(from: result.missingIngredients))")
                    .font(.caption)
                    .foregroundStyle(Color.glindaPink.opacity(0.95))
            }

            Divider().overlay(Color.white.opacity(0.18))

            VStack(alignment: .leading, spacing: 5) {
                Text(AppLocalization.key("Nutrition data sources"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Link(AppLocalization.key("Open Food Facts (ODbL)"), destination: LegalLinks.openFoodFacts)
                Link(AppLocalization.key("USDA FoodData Central"), destination: LegalLinks.usdaFoodDataCentral)
            }
            .font(.caption)
            .tint(Color.wickedGreen)
        }
        .padding(14)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    private func compactMissingList(from missingIngredients: [String]) -> String {
        let topMissing = Array(missingIngredients.prefix(4))
        let listText = topMissing.joined(separator: ", ")
        if missingIngredients.count > topMissing.count {
            return listText + "..."
        }
        return listText
    }
}

private struct NutritionValueRow: View {
    let title: LocalizedStringKey
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
