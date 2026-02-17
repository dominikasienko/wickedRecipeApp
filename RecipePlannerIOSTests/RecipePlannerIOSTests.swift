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

    /// Tests TDEE (Total Daily Energy Expenditure) calculation logic.
    func testTDEECalculation() {
        // Given: A profile with known values
        let profile = UserProfile(
            userId: "test",
            firstName: "Test",
            lastName: "User",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date())!,
            weight: 70.0, // kg
            height: 175.0, // cm
            gender: "Man",
            activityLevel: "Moderate activity", // Multiplier 1.55
            selectedDiets: []
        )
        
        // When: Calculating TDEE
        let tdee = profile.calculateTDEE()
        
        // Then: The value should be greater than zero and follow Mifflin-St Jeor equation
        XCTAssertGreaterThan(tdee, 1500, "TDEE should be a realistic caloric value.")
    }

    // MARK: - WaterManager Tests
    
    /// Tests the logic that determines the daily water goal based on weight and activity.
    func testWaterGoalCalculation() {
        // Note: We use a temporary userId to initialize the manager logic
        let waterManager = WaterManager(userId: "test_id")
        
        // When: Calculating goal for 70kg with High Activity
        waterManager.calculateGoal(weightKg: 70.0, activityLevel: "High activity (daily intense workouts)")
        
        // Then: The goal should be calculated and rounded
        XCTAssertNotNil(waterManager.goal)
        // Calculation: (70 * 30) * 1.2 = 2520 -> rounded to 50s = 2500.0
        XCTAssertEqual(waterManager.goal?.dailyGoalMl, 2500.0, "Water goal should be 2500ml for 70kg high activity.")
    }

    // MARK: - Recipe Model Tests
    
    /// Tests that ingredients are correctly formatted for the Nutrition API.
    func testIngredientDescriptionForAPI() {
        // Given: An ingredient with a decimal quantity
        let ingredient = Ingredient(name: "Flour", quantity: 1.55, unit: "cups")
        
        // When: Getting description
        let description = ingredient.descriptionForAPI
        
        // Then: It should be formatted to one decimal place as per the model logic
        XCTAssertEqual(description, "1.6 cups Flour", "API description should format quantity correctly.")
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
        XCTAssertEqual(record.totalIntakeML, 750, "Total intake should correctly sum all entries.")
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
}
