//
//  ProfileView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.locale) private var locale
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
                
                WickedAmbientGlowLayer(pinkOpacity: 0.4, greenOpacity: 0.3)
                    .ignoresSafeArea()

                if let profile = profileManager.userProfile {
                    List {
                        VStack(spacing: 10) {
                            ProfileImage(url: profile.profileImageURL)
                                .padding(.bottom, 10)
                            
                            Text("\(profile.firstName) \(profile.lastName)")
                                .font(.title).bold()
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .multilineTextAlignment(.center)
                            
                            if let email = authManager.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 20)
                        
                        Section("Personal and Health Data") {
                            DetailRow(title: AppLocalization.key("Date of Birth"), value: .date(profile.dateOfBirth), icon: "calendar")
                            DetailRow(
                                title: AppLocalization.key("Weight"),
                                value: .weight(profile.weight),
                                icon: "scalemass"
                            )
                            DetailRow(title: AppLocalization.key("Height"), value: .height(profile.height), icon: "ruler")
                            DetailRow(
                                title: AppLocalization.key("Sex category for estimate"),
                                value: .localized(profile.localizedGender),
                                icon: AppOptionCatalog.canonicalValue(for: profile.gender, in: AppOptionCatalog.genders) == "man" ? "figure.stand" : "figure.stand.dress"
                            )
                            DetailRow(title: AppLocalization.key("Weight Goal"), value: .localized(profile.localizedWeightGoal), icon: "target")
                            
                            HStack {
                                Label(AppLocalization.key("Activity"), systemImage: "figure.walk")
                                Spacer()
                                Text(profile.localizedActivityLevel)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
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
                                Text(profile.dietLocalizationKeys.map { key in
                                    AppLocalization.resolved(String.LocalizationValue(key), locale: locale)
                                }.joined(separator: ", "))
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
                    .wickedReadableWidth(820)

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
        case localized(LocalizedStringKey)
        case date(Date)
        case weight(Double)
        case height(Double)
    }
    
    let title: LocalizedStringKey
    let value: Value
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            switch value {
            case .text(let string):
                Text(string)
            case .localized(let key):
                Text(key)
            case .date(let date):
                Text(date, style: .date)
            case .weight(let weight):
                HStack(spacing: 0) {
                    Text(weight, format: .number.precision(.fractionLength(1)))
                    Text(verbatim: " kg")
                }
            case .height(let height):
                HStack(spacing: 0) {
                    Text(height, format: .number.precision(.fractionLength(0)))
                    Text(verbatim: " cm")
                }
            }
        }
        .font(.subheadline)
    }
}

// MARK: Sekcja do wyświetlania kalorii i makroskładników
struct NutritionalGoalsSection: View {
    let profile: UserProfile
    
    var body: some View {
        Section(AppLocalization.key("Estimated energy and macro ranges")) {
            if let macros = profile.calculateMacrosIfProfileComplete() {
                HStack {
                    Text(AppLocalization.key("Estimated maintenance energy (EER)"))
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
                        Text("**\(Int(macros.proteinG.lowerGrams.rounded()))–\(Int(macros.proteinG.upperGrams.rounded())) g**")
                    }
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        Text("**\(Int(macros.carbsG.lowerGrams.rounded()))–\(Int(macros.carbsG.upperGrams.rounded())) g**")
                    }
                    HStack {
                        Text("Fats")
                        Spacer()
                        Text("**\(Int(macros.fatG.lowerGrams.rounded()))–\(Int(macros.fatG.upperGrams.rounded())) g**")
                    }
                }
                .font(.subheadline)
                .padding(.top, 5)
                
                Text(AppLocalization.key("Energy is an estimate for weight maintenance, not a weight-loss or weight-gain prescription."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 2)
            } else {
                Text(AppLocalization.key("No energy estimate is available. Check your measurements, sex category, activity category, age, and general-estimate eligibility."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            if let waterReference = profile.calculateWaterGoalMl() {
                HStack {
                    Text(AppLocalization.key("EFSA total-water reference (includes food)"))
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(waterReference)) ml")
                        .bold()
                }
                .padding(.top, 4)
            } else {
                Text(AppLocalization.key("No general water reference is available for this profile."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            DisclosureGroup(AppLocalization.key("Calculation method and limitations")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.key("Energy uses the 2023 NASEM Estimated Energy Requirement equations. They estimate maintenance needs from age, height, weight, sex category, and overall activity; individual error is expected."))
                    Text(AppLocalization.key("The NASEM equations were developed for U.S. and Canadian populations and have not been calibrated specifically for Polish users. Activity categories describe the whole day, not workout count."))
                    Text(AppLocalization.key("Macro amounts are broad acceptable ranges, not exact personal prescriptions. Diet preferences and weight goal do not change these physiological estimates."))
                    Text(AppLocalization.key("EFSA water values are adequate intakes of total water from all beverages and food moisture under moderate conditions. This app logs beverages only."))
                    Link(AppLocalization.key("NASEM 2023 energy equations"), destination: URL(string: "https://www.nationalacademies.org/read/26818/chapter/7")!)
                    Link(AppLocalization.key("National Academies macronutrient ranges"), destination: URL(string: "https://www.nationalacademies.org/read/27957/chapter/5")!)
                    Link(AppLocalization.key("EFSA total-water reference"), destination: URL(string: "https://efsa.onlinelibrary.wiley.com/doi/10.2903/j.efsa.2010.1459")!)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
        .listRowBackground(Color.black.opacity(0.2))
        .listRowSeparatorTint(Color.white.opacity(0.3))
        .foregroundStyle(.white)
    }
}
