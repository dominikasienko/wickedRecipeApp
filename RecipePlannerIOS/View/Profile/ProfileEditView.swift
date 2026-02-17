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
    @State private var savingError: String?
    @State private var isShowingDietSelect = false

    init(profile: UserProfile) {
        _editableProfile = State(initialValue: profile)
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
                    
                    Picker("Gender", selection: $editableProfile.gender) {
                        ForEach(Constants.genders, id: \.self) { Text($0) }
                    }
                }
                
                Section("Parameters") {
                    Stepper("Weight: \(editableProfile.weight, specifier: "%.1f") kg", value: $editableProfile.weight, in: 30...200, step: 0.1)
                    Stepper("Height: \(editableProfile.height, specifier: "%.0f") cm", value: $editableProfile.height, in: 100...250, step: 1)
                    
                    Picker("Activity level", selection: $editableProfile.activityLevel) {
                        ForEach(Constants.activityLevels, id: \.self) { Text($0) }
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
                 Text(savingError ?? "Unknown error.")
            }
        }
    }
    
// MARK: Firebase
    private func saveProfile() async {
        guard let uid = authManager.user?.uid else {
            savingError = "No user ID."
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

            try await profileManager.saveUserProfile(profile: profileToSave, uid: uid)
            await MainActor.run {
                profileManager.userProfile = profileToSave
            }

            waterManager.calculateGoal(
                weightKg: profileToSave.weight,
                activityLevel: profileToSave.activityLevel
            )
            
            dismiss() 
        } catch {
            await MainActor.run {
                self.savingError = error.localizedDescription
            }
        }
    }
}
