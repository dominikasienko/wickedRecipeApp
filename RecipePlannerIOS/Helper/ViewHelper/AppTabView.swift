//
// AppTabView.swift
// RecipePlannerIOS
//
// Created by Dominika Sieńko on 16/11/2025.
//

import SwiftUI
import FirebaseAuth
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enum Zakładek
enum TabItem: String, CaseIterable {
    case home = "Home"
    case favorites = "Favorites"
    case calendar = "Calendar"
    case seasonal = "Seasonal"
    case water = "Water tracker"
    case profile = "Profile"
    case settings = "Settings"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .favorites: return "heart.fill"
        case .calendar: return "calendar"
        case .seasonal: return "leaf.fill"
        case .water: return "drop.fill"
        case .profile: return "person.crop.circle.fill"
        case .settings: return "gear"
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .favorites: return "Favorites"
        case .calendar: return "Calendar"
        case .seasonal: return "Seasonal"
        case .water: return "Water tracker"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: return "tab.home"
        case .favorites: return "tab.favorites"
        case .calendar: return "tab.calendar"
        case .seasonal: return "tab.seasonal"
        case .water: return "tab.waterTracker"
        case .profile: return "tab.profile"
        case .settings: return "tab.settings"
        }
    }

    var screenAccessibilityIdentifier: String {
        switch self {
        case .home: return "screen.home"
        case .favorites: return "screen.favorites"
        case .calendar: return "screen.calendar"
        case .seasonal: return "screen.seasonal"
        case .water: return "screen.waterTracker"
        case .profile: return "screen.profile"
        case .settings: return "screen.settings"
        }
    }
}

struct AppTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(WaterManager.self) private var waterManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(MealPlannerManager.self) private var mealPlanManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedTab: TabItem = .home
    
// MARK: - Main
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                tabContent
                customTabBar(bottomInset: proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            waterManager.refreshCurrentDate()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                waterManager.refreshCurrentDate()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            waterManager.refreshCurrentDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            waterManager.refreshCurrentDate()
        }
    }
    
// MARK: - Widoki Pomocnicze
    
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .home:
                NavigationStack { HomeView() }
            case .favorites:
                FavoritesView()
            case .calendar:
                MealPlannerView()
            case .seasonal:
                NavigationStack { SeasonalCalendarView() }
            case .water:
                WaterTrackerView()
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(selectedTab.screenAccessibilityIdentifier)
    }
    
    private func customTabBar(bottomInset: CGFloat) -> some View {
        let iconBottomPadding = bottomInset > 0 ? max(bottomInset - 22, 6) : 8

        return VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))

            ViewThatFits(in: .horizontal) {
                tabItems(showingTitles: true)
                tabItems(showingTitles: false)
            }
            .frame(height: 56)
            .accessibilityIdentifier("navigation.bar")
        }
        .padding(.bottom, iconBottomPadding)
        .background(.ultraThinMaterial)
        .background(Color.darkBackground.opacity(0.88))
    }

    private func tabItems(showingTitles: Bool) -> some View {
        HStack(alignment: .center, spacing: showingTitles ? 16 : 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 22))

                        if showingTitles {
                            Text(tab.localizedTitle)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? Color.glindaPink : .gray)
                    .padding(.vertical, 8)
                    .frame(
                        minWidth: showingTitles ? 60 : 44,
                        maxWidth: showingTitles ? nil : .infinity,
                        minHeight: 50
                    )
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tab.localizedTitle))
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .padding(.horizontal, 8)
    }
}
