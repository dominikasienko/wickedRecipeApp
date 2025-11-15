//
//  ProfileEditView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import UIKit // Potrzebne dla UIImage
import FirebaseAuth // Wymagane, choć już w managerach
import Observation

// ProfileEditView.swift (W pełni funkcjonalna wersja)

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(WaterManager.self) private var waterManager // KLUCZOWY DODATEK

    // Lokalny stan do edycji (musimy skopiować dane, aby nie modyfikować bezpośrednio profilu)
    @State private var editableProfile: UserProfile
    @State private var selectedImage: UIImage? // Wczytane zdjęcie z ProfileImagePickerView
    @State private var savingError: String?
    
    // Stan do nawigacji do Diet Multi-Select View
    @State private var isShowingDietSelect = false

    // Inicjalizator kopiujący aktualny profil do lokalnego stanu
    init(profile: UserProfile) {
        // Kopiowanie danych do lokalnego stanu, aby edycja była odizolowana
        _editableProfile = State(initialValue: profile)
        
        // Jeśli profileImageURL jest, spróbuj pobrać/ustawić UIImage na starcie
        // UWAGA: W prostszych aplikacjach często pomija się to i ładuje UIImage tylko w pickerze.
        // Dla uproszczenia, zakładamy, że selectedImage jest nil, chyba że użytkownik wybierze nowe.
    }

    var body: some View {
        NavigationStack {
            Form {
                // SEKCJA ZDJĘCIA PROFILOWEGO
                Section("Profile picture") {
                    // Musisz mieć zaimplementowaną logikę ładowania zdjęcia z URL
                    ProfileImagePickerView(profileImage: $selectedImage, profileImageURL: $editableProfile.profileImageURL)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // SEKCJA DANYCH OSOBISTYCH
                Section("Personal information") {
                    TextField("Name", text: $editableProfile.firstName)
                    TextField("Second name", text: $editableProfile.lastName)
                    
                    // Pole daty urodzenia
                    DatePicker("Date of birth", selection: $editableProfile.dateOfBirth, displayedComponents: .date)
                    
                    // Wybór Płci (używa Constants.genders)
                    Picker("Gender", selection: $editableProfile.gender) {
                        ForEach(Constants.genders, id: \.self) { Text($0) }
                    }
                }
                
                // SEKCJA PARAMETRÓW ZDROWOTNYCH
                Section("Parameters") {
                    // Używamy Stepperów dla łatwej edycji liczb
                    Stepper("Weight: \(editableProfile.weight, specifier: "%.1f") kg", value: $editableProfile.weight, in: 30...200, step: 0.1)
                    Stepper("Height: \(editableProfile.height, specifier: "%.0f") cm", value: $editableProfile.height, in: 100...250, step: 1)
                    
                    // Wybór Poziomu Aktywności (używa Constants.activityLevels)
                    Picker("Activity level", selection: $editableProfile.activityLevel) {
                        ForEach(Constants.activityLevels, id: \.self) { Text($0) }
                    }
                }
                
                // SEKCJA WYBORU DIET
                Section("Selected diets") {
                    // Używamy NavigationLink do widoku DietMultiSelectView, który zmienia bindowaną tablicę
                    NavigationLink(destination: DietMultiSelectView(selectedDiets: $editableProfile.selectedDiets)
                        .navigationTitle("Select diets")) {
                            HStack {
                                Text("Nutrition preferences")
                                Spacer()
                                Text("\(editableProfile.selectedDiets.count) selected")
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .bold()
                }
            }
            .alert("Write error", isPresented: .constant(savingError != nil)) {
                 Button("OK") { savingError = nil }
            } message: {
                 Text(savingError ?? "Unknown error.")
            }
        }
    }
    
    // Logika zapisu w Firebase i aktualizacji celów
    private func saveProfile() async {
        guard let uid = authManager.user?.uid else {
            savingError = "No user ID."
            return
        }
        
        do {
            var profileToSave = editableProfile
            
            // 1. Obsługa i przesyłanie zdjęcia (tylko jeśli wybrano nowe zdjęcie)
            if let image = selectedImage {
                let url = try await storageManager.uploadProfileImage(image: image, userId: uid)
                profileToSave.profileImageURL = url
            } else if selectedImage == nil {
                // Jeśli user usunął zdjęcie, ustawiamy URL na nil. Jeśli było nil i nic nie wybrano, zostaje nil.
                profileToSave.profileImageURL = editableProfile.profileImageURL
            }

            // 2. Zapisz profil w Firestore
            try await profileManager.saveUserProfile(profile: profileToSave, uid: uid)
            
            // 3. Zaktualizuj lokalny stan ProfileManager (widok główny natychmiast się odświeży)
            await MainActor.run {
                profileManager.userProfile = profileToSave
            }

            // 4. KLUCZOWY KROK: Przelicz Cel Wody na podstawie nowej wagi/aktywności
            // WaterManager używa tych danych do obliczenia celu!
            waterManager.calculateGoal(
                weightKg: profileToSave.weight,
                activityLevel: profileToSave.activityLevel
            )
            
            dismiss() // Zamknij widok edycji
        } catch {
            await MainActor.run {
                self.savingError = error.localizedDescription
            }
        }
    }
}
