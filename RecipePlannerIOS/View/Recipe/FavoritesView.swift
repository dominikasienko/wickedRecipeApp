//
//  FavoritesView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(RecipeManager.self) private var recipeManager
    
    // --- WICKED STYLE: Paleta kolorów ---
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    // Pobieranie ulubionych przepisów (bez zmian)
    var favoriteRecipes: [Recipe] {
        recipeManager.userRecipes.filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeAreaInsets = proxy.safeAreaInsets
                
                // --- WICKED GLASS: ZStack dla tła i niestandardowego paska ---
                ZStack {
                    // 1. Tło z gradientem
                    darkBackground.ignoresSafeArea()
                    RadialGradient(
                        colors: [wickedGreen.opacity(0.3), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 700
                    ).ignoresSafeArea()
                    RadialGradient(
                        colors: [glindaPink.opacity(0.15), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 500
                    ).ignoresSafeArea()

                    // 2. Główna przewijana zawartość
                    ScrollView {
                        VStack {
                            if favoriteRecipes.isEmpty {
                                // --- WICKED GLASS: Styl dla ContentUnavailableView ---
                                ContentUnavailableView(
                                    label: {
                                        Label {
                                            Text("No favorite recipes")
                                                .font(.title3.bold())
                                        } icon: {
                                            Image(systemName: "heart.slash.fill")
                                                .foregroundStyle(glindaPink) // Różowa ikona
                                        }
                                    },
                                    description: {
                                        Text("Mark the recipe with a heart on the recipe card to display it here.")
                                    }
                                )
                                .foregroundStyle(.secondary) // Jasnoszary tekst na ciemnym tle
                                .padding(.top, 100)
                                
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 20
                                ) {
                                    ForEach(favoriteRecipes) { recipe in
                                        // Używa RecipeGridItem, który już jest ostylowany
                                        RecipeGridItem(recipe: recipe)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        // Padding, aby treść zaczynała się POD szklanym paskiem
                        .padding(.top, safeAreaInsets.top + 80) // 80 = wysokość paska
                        .padding(.bottom, 20)
                    }
                    .edgesIgnoringSafeArea(.top) // Pozwala scrollować "pod" paskiem

                    // 3. --- WICKED GLASS: Niestandardowy "szklany" nagłówek ---
                    VStack(spacing: 0) {
                        HStack {
                            // Tytuł w stylu Wicked
                            Text("Favorites")
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.bold)
                                .foregroundStyle(wickedGreen) // Zielony tytuł
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        .padding(.top, safeAreaInsets.top + 10) // Dopasowanie do Safe Area
                    }
                    .background(.ultraThinMaterial) // EFEKT SZKŁA
                    // Subtelna linia na dole
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.2)), alignment: .bottom)
                    .frame(maxHeight: .infinity, alignment: .top) // Przypnij do góry
                    .edgesIgnoringSafeArea(.top) // Rozciągnij na obszar Safe Area
                    
                }
                .navigationBarHidden(true) // Ukrywamy domyślny pasek
                .preferredColorScheme(.dark) // Wymuszamy ciemny tryb
            }
        }
    }
}
