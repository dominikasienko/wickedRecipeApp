//
//  RecipeDetailView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseStorage
import FirebaseAuth

struct RecipeDetailView: View {
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    
    @State private var selectedTab: Int = 0
    
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    init(recipe: Recipe) {
        self.recipe = recipe
        
        UISegmentedControl.appearance().selectedSegmentTintColor = .init(wickedGreen)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        UISegmentedControl.appearance().backgroundColor = .init(white: 0.1, alpha: 0.3)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = proxy.safeAreaInsets
            
            ZStack(alignment: .top) {
                // 1. Tło
                darkBackground.ignoresSafeArea()
                
                // --- WICKED V2: Kolorowe "Blobs" w tle ---
                // Te elementy będą pięknie rozmywane przez arkusz
                Ellipse()
                    .fill(wickedGreen.opacity(0.4))
                    .frame(width: 300, height: 300)
                    .position(x: 50, y: 200)
                    .blur(radius: 100)
                
                Ellipse()
                    .fill(glindaPink.opacity(0.3))
                    .frame(width: 250, height: 250)
                    .position(x: proxy.size.width - 50, y: proxy.size.height - 100)
                    .blur(radius: 80)
                
                // 2. Główna przewijana treść
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // --- 1. ZDJĘCIE PRZEPISU (HERO IMAGE) ---
                        GeometryReader { geo in
                            let minY = geo.frame(in: .global).minY
                            // --- WICKED V2: Poprawka dla safeAreaInsets ---
                            let isScrollingDown = minY > safeAreaInsets.top
                            
                            AsyncImageView(urlString: recipe.imageURL ?? "")
                                .scaledToFill()
                                .frame(
                                    width: geo.size.width,
                                    // --- WICKED V2: Większe zdjęcie i lepszy stretch ---
                                    height: 350 + (isScrollingDown ? (minY - safeAreaInsets.top) : 0)
                                )
                                .overlay(
                                    LinearGradient(
                                        colors: [.black.opacity(0.3), .clear, .black.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .clipped()
                                .offset(y: isScrollingDown ? -(minY - safeAreaInsets.top) : 0)
                        }
                        // --- WICKED V2: Zwiększona wysokość zdjęcia ---
                        .frame(height: 350)
                        
                        // --- 2. ZAWARTOŚĆ PRZEPISU (ARKUSZ) ---
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Tytuł
                            Text(recipe.name)
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.bold)
                                .foregroundStyle(wickedGreen)
                            
                            // Podstawowe informacje
                            HStack(spacing: 12) {
                                WickedInfoCapsule(
                                    icon: "clock.fill",
                                    text: "\(recipe.preparationTimeMinutes) min"
                                )
                                WickedInfoCapsule(
                                    icon: "person.2.fill",
                                    text: "\(recipe.servings) servings"
                                )
                                WickedInfoCapsule(
                                    icon: "tag.fill",
                                    text: recipe.category
                                )
                                Spacer()
                            }
                            
                            Divider().overlay(glindaPink.opacity(0.5))

                            // --- Przełącznik Składniki / Instrukcje ---
                            Picker("Details", selection: $selectedTab) {
                                Text("Ingredients").tag(0)
                                Text("Instructions").tag(1)
                            }
                            .pickerStyle(.segmented)
                            
                            if selectedTab == 0 {
                                IngredientsLayout(ingredients: recipe.ingredients)
                            } else {
                                InstructionsLayout(instructions: recipe.instructions)
                            }
                            
                            if let notes = recipe.notes, !notes.isEmpty {
                                NotesSection(notes: notes)
                            }
                        }
                        .padding(25)
                        .background(.ultraThinMaterial) // Główne "szkło"
                        .cornerRadius(25, corners: [.topLeft, .topRight])
                        // --- WICKED V2: Większe nałożenie na zdjęcie ---
                        .padding(.top, -50)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)

                // --- 3. PŁYWAJĄCE PRZYCISKI NAWIGACYJNE ---
                HStack {
                    WickedGlassButton(icon: "chevron.backward", action: {
                        dismiss()
                    })
                    
                    Spacer()
                    
                    WickedGlassButton(
                        icon: recipe.isFavorite ? "heart.fill" : "heart",
                        // --- WICKED V2: Serce w kolorze glindaPink ---
                        color: recipe.isFavorite ? glindaPink : .white,
                        action: {
                            toggleFavorite()
                        }
                    )
                    
                    NavigationLink {
                        EditRecipeView(recipe: recipe)
                            .navigationTitle("Edit recipe")
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial) // Pływające szkło
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, safeAreaInsets.top + 5)
                
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
        }
    }
    
    private func toggleFavorite() {
        Task {
            guard let recipeId = recipe.id else { return }
            try? await recipeManager.toggleFavorite(recipeId: recipeId)
        }
    }
}

// MARK: - Widoki Pomocnicze (zaktualizowane do "Frosted-on-Glass")

struct WickedInfoCapsule: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        // --- WICKED V2: Efekt "oszroniony" (Frosted) na szkle ---
        .background(Color.black.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct WickedGlassButton: View {
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                // --- WICKED V2: Prawdziwe "szkło" (bez zmian, było dobrze) ---
                .background(.ultraThinMaterial)
                .foregroundStyle(color)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct IngredientsLayout: View {
    let ingredients: [Ingredient]
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ingredients, id: \.id) { ingredient in
                HStack {
                    Image(systemName: "circle.dotted")
                        .font(.caption)
                        .foregroundStyle(glindaPink)
                    
                    Text(ingredient.name)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("\(Int(ingredient.quantity)) \(ingredient.unit)")
                        .foregroundStyle(.white.opacity(0.7))
                        .bold()
                }
                .padding()
                // --- WICKED V2: Efekt "oszroniony" (Frosted) na szkle ---
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

struct InstructionsLayout: View {
    let instructions: [String]
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(instructions.indices, id: \.self) { index in
                if !instructions[index].isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .bold()
                            .foregroundStyle(glindaPink)
                        
                        Text(instructions[index])
                            .foregroundStyle(.white)
                            .lineSpacing(5)
                    }
                }
            }
        }
    }
}

struct NotesSection: View {
    let notes: String
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(glindaPink.opacity(0.5))
            
            Text("Comments")
                .font(.title2).bold()
                .foregroundStyle(glindaPink)
            
            Text(notes)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(5)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                // --- WICKED V2: Efekt "oszroniony" (Frosted) na szkle ---
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// Narożniki dla .cornerRadius (bez zmian)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
