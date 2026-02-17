//
// AppTabView.swift
// RecipePlannerIOS
//
// Created by Dominika Sieńko on 16/11/2025.
//

import SwiftUI
import FirebaseAuth
import Observation

// MARK: - Enum Zakładek
enum TabItem: String, CaseIterable {
    case home = "Home"
    case favorites = "Favorites"
    case calendar = "Calendar"
    case water = "Water tracker"
    case profile = "Profile"
    case settings = "Settings"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .favorites: return "heart.fill"
        case .calendar: return "calendar"
        case .water: return "drop.fill"
        case .profile: return "person.crop.circle.fill"
        case .settings: return "gear"
        }
    }
}

struct AppTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(WaterManager.self) private var waterManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(MealPlannerManager.self) private var mealPlanManager
    
    @State private var selectedTab: TabItem = .home
    
    private var localizedTabNames: [String] {
        return [
            String(localized: "Home"),
            String(localized: "Favorites"),
            String(localized: "Calendar"),
            String(localized: "Water tracker"),
            String(localized: "Profile"),
            String(localized: "Settings"),
        ]
    }
    
// MARK: - Main
    var body: some View {
        VStack(spacing: 0) {
            tabContent
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
    }
    
// MARK: - Widoki Pomocnicze
    
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .home:
                NavigationStack { HomeView() }
            case .favorites:
                NavigationStack { FavoritesView() }
            case .calendar:
                NavigationStack { MealPlannerView() }
            case .water:
                NavigationStack { WaterTrackerView() }
            case .profile:
                NavigationStack { ProfileView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(TabItem.allCases, id: \.self) { tab in
                        let tabName: String = {
                            if let index = TabItem.allCases.firstIndex(of: tab),
                               index < localizedTabNames.count {
                                return localizedTabNames[index]
                            }
                            
                            return tab.rawValue
                        }()
                        
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 22))
                                
                                Text(tabName)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(selectedTab == tab ? Color.glindaPink : .gray)
                            .padding(.vertical, 8)
                            .frame(minWidth: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 50)
        }
        .background(Color.darkBackground.opacity(0.8).background(.ultraThinMaterial))
    }
}
