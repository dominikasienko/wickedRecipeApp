//
//  Constants.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct Constants {
    static let activityLevels: [String] = [
        String(localized: "No activity (sedentary lifestyle)"),
        String(localized: "Low activity (1-2 workouts per week)"),
        String(localized: "Moderate activity (3-5 workouts per week)"),
        String(localized: "High activity (daily intense workouts)"),
        String(localized: "Very high activity (twice a day)")
    ]

    static let dietOptions: [String] = [
        String(localized: "Basic"),
        String(localized: "Easy to digest"),
        String(localized: "Vegan"),
        String(localized: "Vegetarian"),
        String(localized: "High protein"),
        String(localized: "Low protein"),
        String(localized: "Gluten-free"),
        String(localized: "High fiber")
    ]

    static let genders: [String] = [
        String(localized: "Man"),
        String(localized: "Woman"),
        String(localized: "Other")
    ]
    
    static let mealTypes: [String] = [
        String(localized: "Breakfast"),
        String(localized: "Lunch"),
        String(localized: "Dinner"),
        String(localized: "Snack")
    ]
}

extension Color {
    static let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    static let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    static let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let wickedBlue = Color(red: 87.0/255.0, green: 143.0/255.0, blue: 202.0/255.0)
}
