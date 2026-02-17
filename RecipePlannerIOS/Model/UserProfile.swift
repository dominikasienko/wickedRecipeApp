//
//  UserProfile.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import FirebaseFirestore
import Foundation

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    
    let userId: String
    
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var weight: Double
    var height: Double
    var gender: String
    var activityLevel: String
    var selectedDiets: [String]
    var profileImageURL: String?
    
// MARK: - CodingKeys do Mapowania Firestore
    enum CodingKeys: String, CodingKey {
        case userId = "uid"
        case firstName, lastName, dateOfBirth, weight, height, gender, activityLevel, selectedDiets, profileImageURL
    }

    static func empty(userId: String) -> UserProfile {
        UserProfile(
            userId: userId,
            firstName: "New",
            lastName: "User",
            dateOfBirth: Date(),
            weight: 70.0,
            height: 175.0,
            gender: "Unidentified",
            activityLevel: "Moderate activity",
            selectedDiets: []
        )
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    // MARK: - Obliczenia Kaloryczne
    
    /// Oblicza Podstawową Przemianę Materii (BMR) za pomocą wzoru Mifflina-St Jeor.
    func calculateBMR() -> Double {
        let base = (10 * weight) + (6.25 * height) - (5 * Double(age))
        
        if gender == "Man" {
            return base + 5
        } else {
            return base - 161
        }
    }
    
    /// Oblicza Całkowitą Dzienną Wydatkowanie Energii (TDEE).
    func calculateTDEE() -> Double {
        let bmr = calculateBMR()
        var multiplier: Double
        
        switch activityLevel {
            case "No activity (sedentary lifestyle):":
                multiplier = 1.2
            case "Low activity (1-2 workouts per week)":
                multiplier = 1.375
            case "Moderate activity (3-5 workouts per week)":
                multiplier = 1.55
            case "High activity (daily intense workouts)":
                multiplier = 1.725
            case "Very high activity (twice a day)":
                multiplier = 1.9
            default:
                multiplier = 1.55
        }
        
        return bmr * multiplier
    }
    
    struct Macros {
        let proteinG: Int
        let fatG: Int
        let carbsG: Int
        let totalCalories: Int
    }
    
    /// Oblicza sugerowane makroskładniki (białko, tłuszcz, węglowodany) na podstawie TDEE.
    /// Domyślny rozkład: Białko 25%, Tłuszcze 25%, Węglowodany 50%.
    func calculateMacros() -> Macros {
        let tdee = calculateTDEE()
        
        let proteinPercentage: Double = 0.25
        let fatPercentage: Double = 0.25
        let carbsPercentage: Double = 0.50
        
        let proteinCals = tdee * proteinPercentage
        let fatCals = tdee * fatPercentage
        let carbsCals = tdee * carbsPercentage
        
        let proteinG = Int((proteinCals / 4).rounded())
        let fatG = Int((fatCals / 9).rounded())
        let carbsG = Int((carbsCals / 4).rounded())
            
        let totalCalories = Int(tdee.rounded())
            
        return Macros(proteinG: proteinG, fatG: fatG, carbsG: carbsG, totalCalories: totalCalories)
    }
}
