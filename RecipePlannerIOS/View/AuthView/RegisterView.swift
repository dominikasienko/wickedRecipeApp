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
    private enum Field: Hashable {
        case email
        case password
        case confirmPassword
        case firstName
        case lastName
        case weight
        case height
    }

    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var weightInput = ""
    @State private var heightInput = ""
    @State private var gender = ""
    @State private var selectedActivity = ""
    @State private var selectedWeightGoal = ""
    @State private var canUseGeneralEstimates = false
    @State private var confirmsMinimumAge = false
    @State private var consentsToHealthData = false
    @State private var selectedDiets: [String] = []

    @State private var userImage: UIImage?
    @State private var tempImageURL: String? = nil

    @State private var errorMessage: LocalizedStringKey?
    @State private var isSocialAuthInProgress = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                RegisterAuthBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        header

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                        }

                        socialSection
                        PrivacyPolicyNotice()

                        Text(AppLocalization.key( "Or create your profile manually"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.72))

                        ProfileImagePickerView(profileImage: $userImage, profileImageURL: $tempImageURL)

                        accountSection
                        personalSection
                        physicalSection
                        goalsSection
                        generalEstimatesSection
                        legalConsentSection

                        Button(AppLocalization.key( "Register & Create Profile"), action: registerAndCreateProfile)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.darkBackground)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.wickedGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.top, 6)
                            .disabled(isSocialAuthInProgress || !confirmsMinimumAge || !consentsToHealthData)
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 26)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(11)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.trailing, 24)
                .padding(.top, 16)
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("AppStoreIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 10, y: 4)

            Text(AppLocalization.key( "Create Account"))
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    private var socialSection: some View {
        VStack(spacing: 12) {
            Button(action: signInWithGoogle) {
                HStack(spacing: 12) {
                    RegisterGoogleIcon()

                    Text(AppLocalization.key( "Continue with Google"))
                        .font(.headline.weight(.semibold))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialAuthInProgress)
        }
        .padding(18)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var accountSection: some View {
        RegisterSectionCard(title: AppLocalization.key( "Account Details")) {
            registerField(title: AppLocalization.key( "Email"), icon: "envelope.fill") {
                TextField(AppLocalization.key( "Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key( "Password"), icon: "lock.fill") {
                SecureField(AppLocalization.key( "Password"), text: $password)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key( "Confirm password"), icon: "lock.shield.fill") {
                SecureField(AppLocalization.key( "Confirm password"), text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        focusedField = .firstName
                    }
                    .foregroundStyle(.white)
            }
        }
    }

    private var personalSection: some View {
        RegisterSectionCard(title: AppLocalization.key( "Personal Details")) {
            registerField(title: AppLocalization.key( "Name"), icon: "person.fill") {
                TextField(AppLocalization.key( "Name"), text: $firstName)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .firstName)
                    .onSubmit {
                        focusedField = .lastName
                    }
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key( "Surname"), icon: "person.text.rectangle.fill") {
                TextField(AppLocalization.key( "Surname"), text: $lastName)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .lastName)
                    .onSubmit {
                        focusedField = .weight
                    }
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key( "Date of Birth"), icon: "calendar") {
                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.glindaPink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text("Date of Birth"))
            }
        }
    }

    private var physicalSection: some View {
        RegisterSectionCard(title: AppLocalization.key( "Physical Details")) {
            registerField(title: AppLocalization.key( "Weight (kg)"), icon: "scalemass.fill") {
                TextField(AppLocalization.key("Weight"), text: $weightInput)
                    .keyboardType(.decimalPad)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .weight)
                    .onSubmit {
                        focusedField = .height
                    }
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key( "Height (cm)"), icon: "ruler.fill") {
                TextField(AppLocalization.key("Height"), text: $heightInput)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .height)
                    .onSubmit(registerAndCreateProfile)
                    .foregroundStyle(.white)
            }

            registerField(title: AppLocalization.key("Sex category for estimate"), icon: "person.circle.fill") {
                Picker(AppLocalization.key("Select sex category"), selection: $gender) {
                    Text(AppLocalization.key("Select sex category")).tag("")
                    ForEach(AppOptionCatalog.genders) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var goalsSection: some View {
        RegisterSectionCard(title: AppLocalization.key( "Goals & Activities")) {
            registerField(title: AppLocalization.key("Weight goal"), icon: "target") {
                Picker(AppLocalization.key( "Weight goal"), selection: $selectedWeightGoal) {
                    Text(AppLocalization.key("Select a weight goal")).tag("")
                    ForEach(AppOptionCatalog.weightGoals) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            registerField(title: AppLocalization.key("Overall activity (PAL category)"), icon: "figure.walk.circle.fill") {
                Picker(AppLocalization.key("Select activity category"), selection: $selectedActivity) {
                    Text(AppLocalization.key("Select activity category")).tag("")
                    ForEach(AppOptionCatalog.activityLevels) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(AppLocalization.key("Choose based on movement across the whole day, not only workout frequency."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            NavigationLink(destination: DietMultiSelectView(selectedDiets: $selectedDiets)) {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundStyle(Color.glindaPink)

                    Text(AppLocalization.key( "Select diets"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text("(\(selectedDiets.count))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.glindaPink)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var generalEstimatesSection: some View {
        RegisterSectionCard(title: AppLocalization.key("Health estimate eligibility")) {
            Toggle(isOn: $canUseGeneralEstimates) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalization.key("Use general health estimates"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(AppLocalization.key("Enable only after checking your profile values. Do not use these estimates during pregnancy or breastfeeding or with clinician-directed calorie or fluid limits."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .tint(Color.wickedGreen)
        }
    }

    private var legalConsentSection: some View {
        RegisterSectionCard(title: AppLocalization.key("Privacy and consent")) {
            Toggle(isOn: $confirmsMinimumAge) {
                Text(AppLocalization.key("I confirm that I am at least 16 years old."))
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .tint(Color.wickedGreen)

            Toggle(isOn: $consentsToHealthData) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalization.key("Health data consent"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(AppLocalization.key("I explicitly consent to processing my age, weight, height, activity, dietary preferences and hydration logs to calculate personalized nutrition and hydration estimates. I can withdraw this consent in Settings by permanently deleting my account and associated data."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .tint(Color.wickedGreen)

            Link(AppLocalization.key("Read the Privacy Policy"), destination: LegalLinks.privacyPolicy)
            .font(.footnote.weight(.semibold))
            .tint(Color.wickedGreen)
        }
    }

    private func registerField<Content: View>(
        title: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.glindaPink)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            content()
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .tint(Color.wickedGreen)
        }
    }

    private func registerAndCreateProfile() {
        self.errorMessage = nil

        guard !self.email.isEmpty,
              !self.password.isEmpty,
              !self.firstName.isEmpty,
              !self.lastName.isEmpty else {
            self.errorMessage = AppLocalization.key( "Please fill in all required fields: Email, Password, Name, and Surname.")
            return
        }

        guard self.password == self.confirmPassword else {
            self.errorMessage = AppLocalization.key( "The passwords don't match.")
            return
        }

        guard !self.gender.isEmpty,
              !self.selectedActivity.isEmpty,
              !self.selectedWeightGoal.isEmpty else {
            self.errorMessage = AppLocalization.key("Please select a sex category, activity category, and weight goal.")
            return
        }

        guard confirmsMinimumAge else {
            self.errorMessage = AppLocalization.key("Confirm that you are at least 16 years old to continue.")
            return
        }

        guard consentsToHealthData else {
            self.errorMessage = AppLocalization.key("Consent to health data processing is required to create an account.")
            return
        }

        guard AgeEligibility.isEligible(dateOfBirth: self.dateOfBirth) else {
            self.errorMessage = AppLocalization.key("Date of birth must describe an age between 16 and 100.")
            return
        }

        guard let weight = ProfileMeasurementInput.parse(weightInput), (30...300).contains(weight) else {
            self.errorMessage = AppLocalization.key( "Weight must be between 30 and 300 kg.")
            return
        }

        guard let height = ProfileMeasurementInput.parse(heightInput), (120...250).contains(height) else {
            self.errorMessage = AppLocalization.key( "Height must be between 120 and 250 cm.")
            return
        }

        Task {
            defer { authManager.finishRegistration() }
            do {
                let uid = try await self.authManager.register(email: self.email, password: self.password)

                var imageURL: String? = nil

                if let image = self.userImage {
                    imageURL = try await self.storageManager.uploadProfileImage(image: image, userId: uid)
                }

                let profile = UserProfile(
                    userId: uid,
                    firstName: firstName,
                    lastName: lastName,
                    dateOfBirth: dateOfBirth,
                    weight: weight,
                    height: height,
                    gender: gender,
                    activityLevel: selectedActivity,
                    selectedDiets: selectedDiets,
                    weightGoal: selectedWeightGoal,
                    profileImageURL: imageURL,
                    canUseGeneralEstimates: canUseGeneralEstimates,
                    ageEligibilityConfirmedAt: Date(),
                    healthDataConsentAt: Date(),
                    privacyPolicyVersion: LegalLinks.privacyPolicyVersion
                )

                try await profileManager.saveUserProfile(profile: profile, uid: uid)
                dismiss()
            } catch {
                await MainActor.run {
                    errorMessage = AppLocalization.key("An unknown error occurred.")
                }
            }
        }
    }

    private func signInWithGoogle() {
        Task {
            isSocialAuthInProgress = true
            errorMessage = nil
            defer { isSocialAuthInProgress = false }

            do {
                try await authManager.signInWithGoogle()
                dismiss()
            } catch {
                errorMessage = AppLocalization.key("An unknown error occurred.")
            }
        }
    }
}

private struct RegisterAuthBackground: View {
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            LinearGradient(
                colors: [Color.black, Color.darkBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.wickedGreen.opacity(0.36), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.glindaPink.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

private struct RegisterSectionCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.glindaPink)

            VStack(spacing: 12) {
                content()
            }
        }
        .padding(18)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RegisterGoogleIcon: View {
    var body: some View {
        let glyph = Text("G")
            .font(.system(size: 18, weight: .bold, design: .rounded))

        glyph
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 66.0 / 255.0, green: 133.0 / 255.0, blue: 244.0 / 255.0),
                        Color(red: 219.0 / 255.0, green: 68.0 / 255.0, blue: 55.0 / 255.0),
                        Color(red: 244.0 / 255.0, green: 180.0 / 255.0, blue: 0),
                        Color(red: 15.0 / 255.0, green: 157.0 / 255.0, blue: 88.0 / 255.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}
