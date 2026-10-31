import SwiftUI
import FirebaseAuth
import Observation

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(NotificationManager.self) private var notificationManager

    @State private var waterManager: WaterManager?
    @State private var mealPlanManager: MealPlannerManager?
    @State private var shoppingListManager = ShoppingListManager()
    @State private var loadedUserID: String?
    @State private var loadingUserID: String?
    @State private var showProfileReview = false
    @State private var showingDeleteAccountAlert = false
    @State private var deletePassword = ""
    @State private var deletionInProgress = false
    @State private var flowError: LocalizedStringKey?
    @State private var showFlowError = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                LoginView()
                    .environment(authManager)
                    .environment(profileManager)
            }
        }
        .onChange(of: authManager.user?.uid) { _, userID in
            if let userID {
                loadAccountData(for: userID)
            } else {
                clearSignedOutState()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                clearSignedOutState()
            } else if let userID = authManager.user?.uid {
                loadAccountData(for: userID)
            }
        }
        .onChange(of: authManager.isCompletingRegistration) { _, isCompleting in
            if !isCompleting, let userID = authManager.user?.uid {
                loadAccountData(for: userID)
            }
        }
        .onAppear {
            authManager.setupAuthStateListener()
            if let userID = Auth.auth().currentUser?.uid {
                loadAccountData(for: userID)
            }
        }
        .sheet(isPresented: $showProfileReview) {
            if let profile = profileManager.userProfile, let waterManager {
                ProfileEditView(profile: profile)
                    .environment(authManager)
                    .environment(profileManager)
                    .environment(storageManager)
                    .environment(waterManager)
            }
        }
        .alert(AppLocalization.key("Delete account permanently?"), isPresented: $showingDeleteAccountAlert) {
            if requiresPasswordForDeletion {
                SecureField(AppLocalization.key("Current password"), text: $deletePassword)
            }
            Button(AppLocalization.key("Delete Permanently"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(AppLocalization.key("Cancel"), role: .cancel) { deletePassword = "" }
        } message: {
            Text(AppLocalization.key("Your account and associated data will be permanently removed. If sign-in cannot be verified, deletion will not start."))
        }
        .alert(AppLocalization.key("Account action failed"), isPresented: $showFlowError) {
            Button(AppLocalization.key("OK"), role: .cancel) { flowError = nil }
        } message: {
            Text(flowError ?? AppLocalization.key("An unknown error occurred."))
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if let userID = authManager.user?.uid,
           loadedUserID == userID,
           let waterManager,
           let mealPlanManager,
           let profile = profileManager.userProfile {
            if requiresConsent(for: profile) {
                HealthDataConsentGate(
                    profileAgeEligible: AgeEligibility.isEligible(dateOfBirth: profile.dateOfBirth),
                    isReviewingDefaultProfile: (profileManager.didCreateDefaultProfile && isGoogleAccount)
                        || !AgeEligibility.isEligible(dateOfBirth: profile.dateOfBirth),
                    onAccept: acceptHealthConsent,
                    onReviewProfile: { showProfileReview = true },
                    onSignOut: signOut,
                    onDeleteAccount: { showingDeleteAccountAlert = true },
                    isDeletingAccount: deletionInProgress
                )
            } else {
                AppTabView()
                    .environment(authManager)
                    .environment(profileManager)
                    .environment(storageManager)
                    .environment(recipeManager)
                    .environment(waterManager)
                    .environment(mealPlanManager)
                    .environment(shoppingListManager)
                    .sheet(isPresented: $showProfileReview) {
                        ProfileEditView(profile: profile)
                            .environment(authManager)
                            .environment(profileManager)
                            .environment(storageManager)
                            .environment(waterManager)
                    }
            }
        } else {
            CustomLoadingView(imageName: "launchScreen")
                .environment(authManager)
                .environment(profileManager)
                .environment(storageManager)
                .environment(recipeManager)
                .environment(shoppingListManager)
        }
    }

    private var isGoogleAccount: Bool {
        authManager.user?.providerData.contains { $0.providerID == AuthProviderID.google.rawValue } == true
    }

    private var requiresPasswordForDeletion: Bool {
        authManager.usesPasswordProvider
    }

    private func requiresConsent(for profile: UserProfile) -> Bool {
        profile.healthDataConsentAt == nil
            || profile.ageEligibilityConfirmedAt == nil
            || profile.privacyPolicyVersion != LegalLinks.privacyPolicyVersion
            || !AgeEligibility.isEligible(dateOfBirth: profile.dateOfBirth)
    }

    private func loadAccountData(for userID: String) {
        guard !authManager.isCompletingRegistration,
              loadedUserID != userID,
              loadingUserID != userID else { return }
        loadingUserID = userID
        shoppingListManager.load(forUserID: userID)

        Task {
            do {
                let newWaterManager = WaterManager(userId: userID)
                let newMealPlanManager = MealPlannerManager(userId: userID)
                try await profileManager.fetchUserProfile(userId: userID)
                guard profileManager.userProfile != nil else {
                    throw NSError(domain: "AuthViewError", code: 1)
                }
                try await recipeManager.fetchUserRecipes(userId: userID)
                waterManager = newWaterManager
                mealPlanManager = newMealPlanManager
                loadedUserID = userID
                loadingUserID = nil
            } catch {
                loadingUserID = nil
                flowError = AppLocalization.key("We couldn't load your account data. Please check your connection and try again.")
                showFlowError = true
            }
        }
    }

    private func acceptHealthConsent() {
        guard var profile = profileManager.userProfile,
              let userID = authManager.user?.uid else { return }

        let consentTime = Date()
        profile.ageEligibilityConfirmedAt = consentTime
        profile.healthDataConsentAt = consentTime
        profile.privacyPolicyVersion = LegalLinks.privacyPolicyVersion

        Task {
            do {
                try await profileManager.saveUserProfile(profile: profile, uid: userID)
                if profileManager.didCreateDefaultProfile && isGoogleAccount {
                    showProfileReview = true
                }
            } catch {
                flowError = AppLocalization.key("We couldn't save your consent. No health estimates are available until this is saved.")
                showFlowError = true
            }
        }
    }

    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            flowError = AppLocalization.key("We couldn't sign you out. Please try again.")
            showFlowError = true
        }
    }

    private func deleteAccount() async {
        guard !deletionInProgress,
              let waterManager,
              let mealPlanManager else { return }
        deletionInProgress = true
        defer { deletionInProgress = false }

        do {
            try await authManager.deleteUserAndData(
                password: deletePassword.isEmpty ? nil : deletePassword,
                profileManager: profileManager,
                recipeManager: recipeManager,
                storageManager: storageManager,
                waterManager: waterManager,
                mealPlannerManager: mealPlanManager,
                shoppingListManager: shoppingListManager,
                notificationManager: notificationManager
            )
            deletePassword = ""
        } catch let error as AccountDeletionError {
            switch error {
            case .reauthenticationFailed:
                flowError = AppLocalization.key("We couldn't verify your sign-in. No account data was deleted.")
            case .dataCleanupFailed:
                flowError = AppLocalization.key("Some account data could not be removed. Your sign-in account remains active; some data may already have been removed. Retry or contact support.")
            case .authenticationDeletionFailed:
                flowError = AppLocalization.key("Your personal data was removed, but the sign-in account could not be deleted. Please contact support.")
            case .missingUser, .unsupportedSignInProvider:
                flowError = AppLocalization.key("We couldn't verify your account. Please sign in again or contact support.")
            }
            showFlowError = true
        } catch {
            flowError = AppLocalization.key("Account deletion failed. Please try again or contact support.")
            showFlowError = true
        }
    }

    private func clearSignedOutState() {
        notificationManager.cancelAllWaterReminders()
        waterManager?.clearLocalData()
        mealPlanManager?.clearLocalData()
        waterManager = nil
        mealPlanManager = nil
        loadedUserID = nil
        loadingUserID = nil
        profileManager.clearLocalData()
        recipeManager.clearLocalData()
        shoppingListManager.clearLocalData()
    }
}

private struct HealthDataConsentGate: View {
    let profileAgeEligible: Bool
    let isReviewingDefaultProfile: Bool
    let onAccept: () -> Void
    let onReviewProfile: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let isDeletingAccount: Bool

    @State private var confirmsMinimumAge = false
    @State private var consentsToHealthData = false

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Color.wickedGreen.opacity(0.2), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.wickedGreen)

                    Text(AppLocalization.key("Your privacy and health data"))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(AppLocalization.key("Before the app processes health information, please confirm your age and give explicit consent. You can sign out or delete your account instead."))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.78))

                    if isReviewingDefaultProfile {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalization.key("Your profile needs review before health estimates can be used."))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(AppLocalization.key("Review your age, measurements, activity and dietary preferences. General estimates stay disabled until you check your profile and enable them."))
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                            Button(action: onReviewProfile) {
                                Label(AppLocalization.key("Review your health profile"), systemImage: "person.crop.circle")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .tint(Color.wickedGreen)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Toggle(isOn: $confirmsMinimumAge) {
                        Text(AppLocalization.key("I confirm that I am at least 16 years old."))
                            .foregroundStyle(.white)
                    }
                    .tint(Color.wickedGreen)
                    .accessibilityIdentifier("consent.minimumAge")

                    Toggle(isOn: $consentsToHealthData) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(AppLocalization.key("Health data consent"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(AppLocalization.key("I explicitly consent to processing my age, weight, height, activity, dietary preferences and hydration logs to calculate personalized nutrition and hydration estimates. I can withdraw this consent in Settings by permanently deleting my account and associated data."))
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    .tint(Color.wickedGreen)
                    .accessibilityIdentifier("consent.healthData")

                    if !profileAgeEligible {
                        Text(AppLocalization.key("Update your date of birth to an age of 16 or older before continuing."))
                            .font(.footnote)
                            .foregroundStyle(Color.glindaPink)
                    }

                    Link(AppLocalization.key("Read the Privacy Policy"), destination: LegalLinks.privacyPolicy)
                        .font(.subheadline.weight(.semibold))
                        .tint(Color.wickedGreen)

                    Button(action: onAccept) {
                        HStack {
                            Text(AppLocalization.key("Continue"))
                            if isDeletingAccount { ProgressView().tint(Color.darkBackground) }
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.darkBackground)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.wickedGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!confirmsMinimumAge || !consentsToHealthData || !profileAgeEligible || isDeletingAccount)
                    .accessibilityIdentifier("consent.continue")

                    HStack {
                        Button(AppLocalization.key("Sign out"), action: onSignOut)
                        Spacer()
                        Button(AppLocalization.key("Delete account"), action: onDeleteAccount)
                            .foregroundStyle(.red)
                            .disabled(isDeletingAccount)
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Color.white.opacity(0.82))
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}
