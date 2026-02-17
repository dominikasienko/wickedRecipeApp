//
//  ProfileView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    
    @State private var showingEditView = false
    @State private var showingPasswordResetAlert = false
    
// MARK: - Profile Image Subview
    
    @ViewBuilder
    private func ProfileImage(url: String?) -> some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.badge.exclam")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.gray.opacity(0.8))
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.wickedGreen, lineWidth: 3)
        )
    }

// MARK: - View Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.glindaPink.opacity(0.4))
                    .frame(width: 300, height: 300)
                    .position(x: 350, y: 50)
                    .blur(radius: 100)
                    .ignoresSafeArea()
                
                Ellipse()
                    .fill(Color.wickedGreen.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .position(x: 50, y: 800)
                    .blur(radius: 80)
                    .ignoresSafeArea()

                if let profile = profileManager.userProfile {
                    List {
                        VStack(spacing: 10) {
                            ProfileImage(url: profile.profileImageURL)
                                .padding(.bottom, 10)
                            
                            Text("\(profile.firstName) \(profile.lastName)")
                                .font(.title).bold()
                                .foregroundStyle(.white)
                            
                            if let email = authManager.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 20)
                        
                        Section("Personal and Health Data") {
                            DetailRow(title: "Date of Birth", value: .date(profile.dateOfBirth), icon: "calendar")
                            DetailRow(title: "Weight", value: .text("\(profile.weight, default: "%.1f") kg"), icon: "scalemass")
                            DetailRow(title: "Height", value: .text("\(profile.height, default: "%.0f") cm"), icon: "ruler")
                            DetailRow(title: "Gender", value: .text(profile.gender), icon: profile.gender == "Man" ? "figure.stand" : "figure.stand.dress")
                            
                            HStack {
                                Label("Activity", systemImage: "figure.walk")
                                Spacer()
                                Text(profile.activityLevel)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                            }
                        }
                        .headerProminence(.increased)
                        .listRowBackground(Color.black.opacity(0.2))
                        .listRowSeparatorTint(Color.white.opacity(0.3))
                        .foregroundStyle(.white)
                        
                        Section("Selected Diets") {
                            if profile.selectedDiets.isEmpty {
                                Text("No diets selected")
                                    .foregroundStyle(Color.gray)
                            } else {
                                Text(profile.selectedDiets.joined(separator: ", "))
                            }
                        }
                        .headerProminence(.increased)
                        .listRowBackground(Color.black.opacity(0.2))
                        .listRowSeparatorTint(Color.white.opacity(0.3))
                        .foregroundStyle(.white)
                        
                        NutritionalGoalsSection(profile: profile)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .preferredColorScheme(.dark)

                } else {
                    ContentUnavailableView("Loading profile...", systemImage: "person.circle")
                }
            }
            .navigationTitle("My Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditView = true
                    } label: {
                        Text("Edit")
                            .foregroundStyle(Color.wickedGreen)
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                ProfileEditView(profile: profileManager.userProfile!)
            }
        }
    }
}

// MARK: - Helper Components

struct DetailRow: View {
    enum Value {
        case text(String)
        case date(Date)
    }
    
    let title: String
    let value: Value
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            switch value {
            case .text(let string):
                Text(string)
            case .date(let date):
                Text(date, style: .date)
            }
        }
        .font(.subheadline)
    }
}

// MARK: Sekcja do wyświetlania kalorii i makroskładników
struct NutritionalGoalsSection: View {
    let profile: UserProfile
    
    var body: some View {
        let macros = profile.calculateMacros()
        
        Section("Calorie Requirements (TDEE)") {
            HStack {
                Text("Daily Calorie Intake")
                    .font(.headline)
                    .foregroundStyle(Color.glindaPink)
                Spacer()
                Text("\(macros.totalCalories) kcal")
                    .font(.headline)
                    .bold()
            }
            
            VStack(spacing: 5) {
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("**\(macros.proteinG) g**")
                }
                HStack {
                    Text("Carbohydrates")
                    Spacer()
                    Text("**\(macros.carbsG) g**")
                }
                HStack {
                    Text("Fats")
                    Spacer()
                    Text("**\(macros.fatG) g**")
                }
            }
            .font(.subheadline)
            .padding(.top, 5)
        }
        .headerProminence(.increased)
        .listRowBackground(Color.black.opacity(0.2))
        .listRowSeparatorTint(Color.white.opacity(0.3))
        .foregroundStyle(.white)
    }
}
