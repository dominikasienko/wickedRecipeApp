//
//  Constants.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct Constants {
    static var activityLevels: [LocalizedStringKey] { AppOptionCatalog.activityLevels.map(\.title) }
    static var dietOptions: [LocalizedStringKey] { AppOptionCatalog.dietOptions.map(\.title) }
    static var genders: [LocalizedStringKey] { AppOptionCatalog.genders.map(\.title) }
    static var mealTypes: [LocalizedStringKey] { AppOptionCatalog.mealTypes.map(\.title) }
    static var weightGoals: [LocalizedStringKey] { AppOptionCatalog.weightGoals.map(\.title) }
}

extension Color {
    static let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    static let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    static let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let wickedBlue = Color(red: 87.0/255.0, green: 143.0/255.0, blue: 202.0/255.0)
}
