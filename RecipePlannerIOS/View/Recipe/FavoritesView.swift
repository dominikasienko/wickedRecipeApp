//
//  FavoritesView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(RecipeManager.self) private var recipeManager
    
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    var favoriteRecipes: [Recipe] {
        recipeManager.userRecipes.filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeAreaInsets = proxy.safeAreaInsets
                
                ZStack {
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

                    ScrollView {
                        VStack(spacing: 20) {
                            if favoriteRecipes.isEmpty {
                                ContentUnavailableView(
                                    label: {
                                        Label {
                                            Text("No favorite recipes")
                                                .font(.title3.bold())
                                        } icon: {
                                            Image(systemName: "heart.slash.fill")
                                                .foregroundStyle(glindaPink)
                                        }
                                    },
                                    description: {
                                        Text("Mark the recipe with a heart on the recipe card to display it here.")
                                    }
                                )
                                .foregroundStyle(.secondary)
                                .padding(.top, 100)
                                
                            } else {
                                LazyVStack(spacing: 20) {
                                    ForEach(favoriteRecipes) { recipe in
                                        NavigationLink {
                                            RecipeDetailView(recipe: recipe)
                                        } label: {
                                            FavoriteRecipeRow(recipe: recipe, glindaPink: glindaPink)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, safeAreaInsets.top + 80)
                        .padding(.bottom, 20)
                    }
                    .edgesIgnoringSafeArea(.top)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Favorites")
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.bold)
                                .foregroundStyle(wickedGreen)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        .padding(.top, safeAreaInsets.top + 10)
                    }
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.2)), alignment: .bottom)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .edgesIgnoringSafeArea(.top)
                    
                }
                .navigationBarHidden(true)
                .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: WIDOK POMOCNICZY

struct FavoriteRecipeRow: View {
    let recipe: Recipe
    let glindaPink: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImageView(urlString: recipe.imageURL ?? "")
                .scaledToFill()
                .frame(height: 250)
                .clipped()
            
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.black.opacity(0.9), .black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 150)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                
                Text(recipe.category.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(glindaPink)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(glindaPink.opacity(0.2))
                    .clipShape(Capsule())
                
                HStack(spacing: 15) {
                    Label("\(recipe.preparationTimeMinutes) min", systemImage: "clock")
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
