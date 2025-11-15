//
//  ManagersEnvironment.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/11/2025.
//

import SwiftUI

private struct AuthManagerKey: EnvironmentKey {
    static let defaultValue = AuthManager()
}

private struct ProfileManagerKey: EnvironmentKey {
    static let defaultValue = ProfileManager()
}

private struct StorageManagerKey: EnvironmentKey {
    static let defaultValue = StorageManager()
}

private struct RecipeManagerKey: EnvironmentKey {
    static let defaultValue = RecipeManager()
}

private struct WaterManagerKey: EnvironmentKey {
    // Optional in environment because it’s userId-scoped and created post-login
    static let defaultValue: WaterManager? = nil
}

private struct MealPlannerManagerKey: EnvironmentKey {
    // Optional in environment because it’s userId-scoped and created post-login
    static let defaultValue: MealPlannerManager? = nil
}

extension EnvironmentValues {
    var authManager: AuthManager {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }

    var profileManager: ProfileManager {
        get { self[ProfileManagerKey.self] }
        set { self[ProfileManagerKey.self] = newValue }
    }

    var storageManager: StorageManager {
        get { self[StorageManagerKey.self] }
        set { self[StorageManagerKey.self] = newValue }
    }

    var recipeManager: RecipeManager {
        get { self[RecipeManagerKey.self] }
        set { self[RecipeManagerKey.self] = newValue }
    }

    var waterManager: WaterManager? {
        get { self[WaterManagerKey.self] }
        set { self[WaterManagerKey.self] = newValue }
    }

    var mealPlannerManager: MealPlannerManager? {
        get { self[MealPlannerManagerKey.self] }
        set { self[MealPlannerManagerKey.self] = newValue }
    }
}
