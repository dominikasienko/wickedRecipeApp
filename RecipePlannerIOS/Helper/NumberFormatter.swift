//
//  NumberFormatter.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import Foundation

extension NumberFormatter {
    static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

enum ProfileMeasurementInput {
    /// Accepts either decimal separator and returns the app's canonical metric value.
    static func parse(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasComma = trimmed.contains(",")
        let hasPeriod = trimmed.contains(".")
        var normalized = trimmed.replacingOccurrences(of: " ", with: "")

        if hasComma && hasPeriod {
            let decimalSeparator = (normalized.lastIndex(of: ",")! > normalized.lastIndex(of: ".")!) ? "," : "."
            let groupingSeparator = decimalSeparator == "," ? "." : ","
            normalized = normalized.replacingOccurrences(of: groupingSeparator, with: "")
            normalized = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
        } else {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
