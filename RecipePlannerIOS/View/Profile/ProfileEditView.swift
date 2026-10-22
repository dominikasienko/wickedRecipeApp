//
//  ProfileEditView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import Observation

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(WaterManager.self) private var waterManager

    @State private var editableProfile: UserProfile
    @State private var selectedImage: UIImage?
    @State private var savingError: LocalizedStringKey?
    @State private var isShowingDietSelect = false

    init(profile: UserProfile) {
        _editableProfile = State(initialValue: profile.canonicalizedForStorage())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile picture") {
                    ProfileImagePickerView(profileImage: $selectedImage, profileImageURL: $editableProfile.profileImageURL)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("Personal information") {
                    TextField("Name", text: $editableProfile.firstName)
                    TextField("Second name", text: $editableProfile.lastName)
                    DatePicker("Date of birth", selection: $editableProfile.dateOfBirth, displayedComponents: .date)
                    
                    Picker(AppLocalization.key("Sex category for estimate"), selection: $editableProfile.gender) {
                        ForEach(AppOptionCatalog.genders) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    Text(AppLocalization.key("The energy equation uses male or female reference categories. No equation is applied to Other."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Parameters") {
                    Stepper("Weight: \(editableProfile.weight, specifier: "%.1f") kg", value: $editableProfile.weight, in: 30...300, step: 0.1)
                    Stepper("Height: \(editableProfile.height, specifier: "%.0f") cm", value: $editableProfile.height, in: 120...250, step: 1)
                    
                    Picker(AppLocalization.key("Weight goal"), selection: Binding<String>(
                        get: { editableProfile.weightGoal ?? "" },
                        set: { editableProfile.weightGoal = $0 }
                    )) {
                        Text(AppLocalization.key("Select a weight goal")).tag("")
                        ForEach(AppOptionCatalog.weightGoals) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    
                    Picker(AppLocalization.key("Overall activity (PAL category)"), selection: $editableProfile.activityLevel) {
                        Text(AppLocalization.key("Select activity category")).tag("")
                        ForEach(AppOptionCatalog.activityLevels) { option in
                            Text(option.title).tag(option.id)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { editableProfile.canUseGeneralEstimates ?? false },
                        set: { editableProfile.canUseGeneralEstimates = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLocalization.key("Use general health estimates"))
                            Text(AppLocalization.key("Enable only after checking your profile values. Do not use these estimates during pregnancy or breastfeeding or with clinician-directed calorie or fluid limits."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Selected diets") {
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
                 Text(savingError ?? AppLocalization.key("An unknown error occurred."))
            }
        }
    }
    
// MARK: Firebase
    private func saveProfile() async {
        guard let uid = authManager.user?.uid else {
            savingError = AppLocalization.key("An unknown error occurred.")
            return
        }
        
        if !AgeEligibility.isEligible(dateOfBirth: editableProfile.dateOfBirth) {
            savingError = AppLocalization.key("Date of birth must describe an age between 16 and 100.")
            return
        }
        
        if !(30...300).contains(editableProfile.weight) {
            savingError = AppLocalization.key( "Weight must be between 30 and 300 kg.")
            return
        }
        
        if !(120...250).contains(editableProfile.height) {
            savingError = AppLocalization.key( "Height must be between 120 and 250 cm.")
            return
        }
        
        do {
            var profileToSave = editableProfile
            
            if let image = selectedImage {
                let url = try await storageManager.uploadProfileImage(image: image, userId: uid)
                profileToSave.profileImageURL = url
            } else if selectedImage == nil {
                profileToSave.profileImageURL = editableProfile.profileImageURL
            }

            profileToSave = profileToSave.canonicalizedForStorage()

            try await profileManager.saveUserProfile(profile: profileToSave, uid: uid)
            await MainActor.run {
                profileManager.userProfile = profileToSave
            }

            waterManager.calculateGoal(profile: profileToSave)
            
            dismiss() 
        } catch {
            await MainActor.run {
                self.savingError = AppLocalization.key("An unknown error occurred.")
            }
        }
    }
}
