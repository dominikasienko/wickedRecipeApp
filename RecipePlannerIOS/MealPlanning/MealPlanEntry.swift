//
//  MealPlanEntry.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import Foundation
import FirebaseFirestore

struct MealPlanEntry: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var mealType: String
    var recipeId: String
    var recipeName: String
    
    var plannedServings: Int
    
    init(userId: String, date: Date, mealType: String, recipeId: String, recipeName: String, plannedServings: Int) {
        self.userId = userId
        self.date = date.startOfDay
        self.mealType = mealType
        self.recipeId = recipeId
        self.recipeName = recipeName
        self.plannedServings = plannedServings
    }
}

extension Date {
    /// Zwraca datę ustawioną na początek dnia (godzina 00:00:00)
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Zwraca datę ustawioną na pierwszy dzień bieżącego miesiąca (o 00:00:00)
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        // Force unwrap is safe here because year+month are valid for any Date
        return calendar.date(from: components) ?? self.startOfDay
    }
    
    /// Sprawdza, czy data jest taka sama jak inna data (ignorując czas)
    func isSameDay(as otherDate: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: otherDate)
    }
}

