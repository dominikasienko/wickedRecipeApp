//
//  RegisterView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth

struct RegisterView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss

    // Pola formularza
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var weight: Double = 70
    @State private var height: Double = 175
    @State private var gender = Constants.genders[0]
    @State private var selectedActivity = Constants.activityLevels[0]
    @State private var selectedDiets: [String] = []
    
    // Zmienne zdjęcia
    @State private var userImage: UIImage?
    @State private var tempImageURL: String? = nil
    
    @State private var errorMessage: String?

    // --- WICKED STYLE: Paleta kolorów ---
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        // --- NavigationStack jest POPRAWNY (dzięki niemu diety działają) ---
        NavigationStack {
            
            // --- WICKED GLASS: Zastępujemy 'Form' przez 'ZStack' i 'ScrollView' ---
            ZStack {
                // Tło z gradientem
                darkBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [wickedGreen.opacity(0.3), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                ).ignoresSafeArea()
                
                // --- WICKED GLASS: Przycisk do zamykania sheet'a ---
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .padding([.top, .trailing], 20)
                    Spacer()
                }
                .zIndex(2) // Upewnij się, że jest nad kartą

                // --- WICKED GLASS: Główna "szklana karta" formularza ---
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Tytuł
                        Text("Create Account")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundStyle(wickedGreen)
                            .padding(.bottom, 10)
                        
                        // --- Błąd ---
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10) // Dodatkowy padding dla błędu
                        }

                        // --- Sekcja Zdjęcia ---
                        ProfileImagePickerView(profileImage: $userImage, profileImageURL: $tempImageURL)

                        // --- Sekcja Konto ---
                        WickedSectionHeader(title: "Account Details")
                        
                        WickedFrostedRow {
                            Image(systemName: "envelope.fill")
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                        }
                        
                        WickedFrostedRow {
                            Image(systemName: "lock.fill")
                            SecureField("Password", text: $password)
                        }
                        
                        WickedFrostedRow {
                            Image(systemName: "lock.shield.fill")
                            SecureField("Confirm password", text: $confirmPassword)
                        }

                        // --- Sekcja Dane Osobowe ---
                        WickedSectionHeader(title: "Personal Details")
                        
                        WickedFrostedRow {
                            Image(systemName: "person.fill")
                            TextField("Name", text: $firstName)
                        }
                        
                        WickedFrostedRow {
                            Image(systemName: "person.text.rectangle.fill")
                            TextField("Surname", text: $lastName)
                        }
                        
                        WickedFrostedRow(isPicker: true) {
                            Image(systemName: "calendar")
                            Text("Date of Birth")
                            Spacer()
                            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                .labelsHidden()
                                .colorInvert()
                                .colorMultiply(glindaPink)
                        }

                        // --- Sekcja Szczegóły Fizyczne ---
                        WickedSectionHeader(title: "Physical Details")
                        
                        WickedFrostedRow {
                            Image(systemName: "scalemass.fill")
                            Text("Weight (kg)")
                            Spacer()
                            TextField("Weight", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        
                        WickedFrostedRow {
                            Image(systemName: "ruler.fill")
                            Text("Height (cm)")
                            Spacer()
                            TextField("Height", value: $height, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        
                        // --- POPRAWKA: Zmieniony layout Pickera (Gender) ---
                        WickedFrostedRow(isPicker: true) {
                            Image(systemName: "person.circle.fill")
                            Text("Gender")
                            Spacer()
                            Picker("Gender", selection: $gender) {
                                ForEach(Constants.genders, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        
                        // --- Sekcja Cele i Aktywność ---
                        WickedSectionHeader(title: "Goals & Activities")
                        
                        // --- POPRAWKA: Zmieniony layout Pickera (Activity) ---
                        WickedFrostedRow(isPicker: true) {
                            Image(systemName: "figure.walk.circle.fill")
                            Text("Activity level")
                            Spacer()
                            Picker("Activity level", selection: $selectedActivity) {
                                ForEach(Constants.activityLevels, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        
                        // Nawigacja do wyboru diet (Działa poprawnie)
                        NavigationLink(destination: DietSelectView(selectedDiets: $selectedDiets)) {
                            WickedFrostedRow {
                                Image(systemName: "fork.knife.circle.fill")
                                Text("Select diets")
                                Spacer()
                                Text("(\(selectedDiets.count))")
                                    .foregroundStyle(glindaPink)
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                            }
                        }
                        
                        // --- Przycisk Zarejestruj ---
                        Button("Register & Create Profile", action: registerAndCreateProfile)
                            .font(.headline)
                            .foregroundStyle(darkBackground)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(wickedGreen)
                            .clipShape(Capsule())
                            .padding(.top, 20)
                        
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true) // Ukrywamy pasek nawigacji stosu
        } // --- Koniec NavigationStack ---
    }

    //
    // Logika rejestracji (Z DODANĄ WALIDACJĄ)
    //
    private func registerAndCreateProfile() {
        self.errorMessage = nil
        
        // --- POPRAWKA: Walidacja pustych pól ---
        guard !self.email.isEmpty,
              !self.password.isEmpty,
              !self.firstName.isEmpty,
              !self.lastName.isEmpty else {
            self.errorMessage = "Please fill in all required fields: Email, Password, Name, and Surname."
            return
        }
         
        guard self.password == self.confirmPassword else {
            self.errorMessage = "The passwords don't match."
            return
        }
        
        guard !self.selectedDiets.isEmpty else {
            self.errorMessage = "Select at least one diet option."
            return
        }
        
        Task {
            do {
                let uid = try await self.authManager.register(email: self.email, password: self.password)
                
                var imageURL: String? = nil
                
                if let image = self.userImage {
                    imageURL = try await self.storageManager.uploadProfileImage(image: image, userId: uid)
                }
                
                let profile = UserProfile(
                    userId: uid,
                    firstName: firstName, lastName: lastName,
                    dateOfBirth: dateOfBirth, weight: weight, height: height,
                    gender: gender, activityLevel: selectedActivity,
                    selectedDiets: selectedDiets,
                    profileImageURL: imageURL
                )
                
                try await profileManager.saveUserProfile(profile: profile, uid: uid)
                
                dismiss()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// --- Widoki pomocnicze (bez zmian) ---

struct WickedSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.8)) // glindaPink
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }
}

struct WickedFrostedRow<Content: View>: View {
    var isPicker: Bool = false
    @ViewBuilder var content: Content
    
    private let glindaPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    private let wickedGreen = Color(red: 0.0, green: 0.6, blue: 0.2)

    var body: some View {
        HStack(spacing: 15) {
            content
        }
        .foregroundStyle(isPicker ? .white : glindaPink.opacity(0.8))
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .tint(wickedGreen)
        .colorScheme(.dark)
    }
}
