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

    @State private var editableProfile: UserProfile
    @State private var referenceWeightInput: String
    @State private var selectedImage: UIImage?
    @State private var profileImageEditState: ProfileImageEditState = .unchanged
    @State private var savingError: LocalizedStringKey?
    @State private var dismissAfterAlert = false
    @State private var isShowingDietSelect = false
    @State private var isSaving = false

    init(profile: UserProfile) {
        _editableProfile = State(initialValue: profile.canonicalizedForStorage())
        _referenceWeightInput = State(initialValue: profile.referenceWeightKg.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile picture") {
                    ProfileImagePickerView(
                        profileImage: $selectedImage,
                        profileImageURL: $editableProfile.profileImageURL,
                        onImageSelected: { profileImageEditState = .replacement },
                        onImageRemoved: { profileImageEditState = .removal }
                    )
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

                Section(AppLocalization.key("Hydration estimate")) {
                    Text(AppLocalization.key("If your BMI is 25 or higher, the NCEŻ 30 ml/kg estimate needs an appropriate reference weight. Enter one only if advised by a clinician or dietitian; leave blank if you do not have one."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(AppLocalization.key("Reference weight advised by a clinician or dietitian (kg)"), text: $referenceWeightInput)
                        .keyboardType(.decimalPad)
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
            .wickedReadableWidth(760)
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert(
                "Write error",
                isPresented: Binding(
                    get: { savingError != nil },
                    set: { if !$0 { savingError = nil } }
                )
            ) {
                 Button("OK") {
                     savingError = nil
                     if dismissAfterAlert {
                         dismissAfterAlert = false
                         dismiss()
                     }
                 }
            } message: {
                 Text(savingError ?? AppLocalization.key("An unknown error occurred."))
            }
        }
    }
    
// MARK: Firebase
    private func saveProfile() async {
        guard !isSaving else { return }
        guard let uid = authManager.user?.uid else {
            savingError = AppLocalization.key("An unknown error occurred.")
            return
        }

        isSaving = true
        defer { isSaving = false }
        
        if !AgeEligibility.isEligible(dateOfBirth: editableProfile.dateOfBirth) {
            savingError = AppLocalization.key("Date of birth must describe an age between 16 and 100.")
            return
        }
        
        if !HydrationCalculationService.supportedWeightRangeKg.contains(editableProfile.weight) {
            savingError = AppLocalization.key( "Weight must be between 30 and 300 kg.")
            return
        }
        
        if !HydrationCalculationService.supportedHeightRangeCm.contains(editableProfile.height) {
            savingError = AppLocalization.key( "Height must be between 120 and 250 cm.")
            return
        }

        let trimmedReferenceWeight = referenceWeightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedReferenceWeight.isEmpty {
            editableProfile.referenceWeightKg = nil
        } else {
            guard let referenceWeight = ProfileMeasurementInput.parse(trimmedReferenceWeight),
                  HydrationCalculationService.supportedWeightRangeKg.contains(referenceWeight),
                  referenceWeight < editableProfile.weight else {
                savingError = AppLocalization.key("Reference weight must be between 30 and 300 kg and lower than current weight. Enter it only if advised by a clinician or dietitian.")
                return
            }
            editableProfile.referenceWeightKg = referenceWeight
        }
        
        do {
            var profileToSave = editableProfile

            switch profileImageEditState {
            case .unchanged:
                break
            case .replacement:
                guard let image = selectedImage else {
                    savingError = AppLocalization.key("The selected profile photo is unavailable. Please choose it again.")
                    return
                }
                let url = try await storageManager.uploadProfileImage(image: image, userId: uid)
                guard let updatedProfile = profileImageEditState.applying(to: profileToSave, replacementURL: url) else {
                    savingError = AppLocalization.key("The selected profile photo is unavailable. Please choose it again.")
                    return
                }
                profileToSave = updatedProfile
            case .removal:
                guard let updatedProfile = profileImageEditState.applying(to: profileToSave) else { return }
                profileToSave = updatedProfile
            }

            profileToSave = profileToSave.canonicalizedForStorage()

            try await profileManager.saveUserProfile(
                profile: profileToSave,
                uid: uid,
                removingProfileImage: profileImageEditState == .removal
            )
            if profileImageEditState == .removal {
                do {
                    try await storageManager.deleteProfileImage(userId: uid)
                } catch {
                    savingError = AppLocalization.key("Your profile photo was removed, but its stored file could not be deleted. It is no longer linked to your profile.")
                    dismissAfterAlert = true
                    return
                }
            }

            dismiss() 
        } catch {
            savingError = AppLocalization.key("We couldn't save your profile changes. Please check your connection and try again.")
        }
    }
}
