//
//  SettingsView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 20/11/2025.
//

import SwiftUI
import Observation
import FirebaseAuth

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { self.rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(WaterManager.self) private var waterManager
    @Environment(NotificationManager.self) private var notificationManager

    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    @State private var deleteInProgress = false
    @State private var errorDeleting = false
    
    @State private var showingPasswordAlert = false
    @State private var passwordAlertMessage = ""
    @State private var showingResetWaterAlert = false
    
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @AppStorage("waterReminderEnabled") private var waterReminderEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                WickedGlassBackground()
                content
            }
            .navigationTitle("Settings")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.darkBackground.opacity(0.5), for: .navigationBar)
            .preferredColorScheme(selectedTheme.colorScheme)
            .modifier(SettingsAlerts(
                showingLogoutAlert: $showingLogoutAlert,
                showingDeleteAlert: $showingDeleteAlert,
                showingPasswordAlert: $showingPasswordAlert,
                showingResetWaterAlert: $showingResetWaterAlert,
                errorDeleting: $errorDeleting,
                passwordAlertMessage: $passwordAlertMessage,
                onLogout: { try? authManager.signOut() },
                onDelete: { Task { await handleDeleteAccount() } },
                onResetWater: { Task { await resetWaterHistory() } }
            ))
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let profile = profileManager.userProfile {
            List {
                PersonalizationSection(
                    selectedTheme: $selectedTheme
                )
                
                NotificationsSection(
                    waterReminderEnabled: $waterReminderEnabled,
                    onResetWaterTap: { showingResetWaterAlert = true }
                )
                .onChange(of: waterReminderEnabled) { _, newValue in
                    notificationManager.toggleWaterReminders(isOn: newValue)
                }
                
                AccountSection(
                    profile: profile,
                    onResetPassword: resetPassword,
                    onLogoutTap: { showingLogoutAlert = true },
                    onDeleteTap: { showingDeleteAlert = true },
                    deleteInProgress: deleteInProgress
                )
                
                AboutSection(sendFeedback: sendFeedback)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .foregroundStyle(.white)
        } else {
            ProgressView()
                .tint(.white)
        }
    }
    
// MARK: - LOGIKA
    
    private func handleDeleteAccount() async {
        guard !deleteInProgress else { return }
        deleteInProgress = true
        errorDeleting = false
        
        do {
            try await authManager.deleteUserAndData(
                profileManager: profileManager,
                recipeManager: recipeManager,
                storageManager: storageManager
            )
        } catch {
            print("SettingsView: Failed to delete account: \(error.localizedDescription)")
            errorDeleting = true
            deleteInProgress = false
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Wysyła e-mail resetujący hasło
    private func resetPassword() {
        guard let email = authManager.user?.email else {
            passwordAlertMessage = "Could not find your email address."
            showingPasswordAlert = true
            return
        }
        
        Task {
            do {
                try await authManager.sendPasswordReset(withEmail: email)
                passwordAlertMessage = "A password reset link has been sent to \(email)."
            } catch {
                passwordAlertMessage = "Failed to send reset email: \(error.localizedDescription)"
            }
            showingPasswordAlert = true
        }
    }
    
    /// Wysyła e-mail
    private func sendFeedback() {
        let email = "dominikasienko01@gmail.com"
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func resetWaterHistory() async {
        do {
            try await waterManager.deleteAllWaterRecords()
        } catch {}
    }
}

// MARK: - Subviews

private struct WickedGlassBackground: View {
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            Ellipse()
                .fill(Color.glindaPink.opacity(0.3))
                .frame(width: 300, height: 300)
                .position(x: 50, y: 100)
                .blur(radius: 100)
                .ignoresSafeArea()
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.3))
                .frame(width: 250, height: 250)
                .position(x: 300, y: 700)
                .blur(radius: 80)
                .ignoresSafeArea()
        }
    }
}

private struct PersonalizationSection: View {
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        Section(header: Text("Personalization").foregroundStyle(.gray)) {
            Picker("Theme", selection: $selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }
}

// MARK: --- SEKCJA POWIADOMIEŃ ---
private struct NotificationsSection: View {
    @Binding var waterReminderEnabled: Bool
    let onResetWaterTap: () -> Void
    
    var body: some View {
        Section(header: Text("Notifications & Data").foregroundStyle(.gray)) {
            Toggle("Water Reminders", isOn: $waterReminderEnabled)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)
            
            Button(action: onResetWaterTap) {
                Label("Reset all water history", systemImage: "drop.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }
}

// MARK: Konto

private struct AccountSection: View {
    let profile: UserProfile
    let onResetPassword: () -> Void
    let onLogoutTap: () -> Void
    let onDeleteTap: () -> Void
    let deleteInProgress: Bool
    
    @Environment(ProfileManager.self) private var profileManager
    
    var body: some View {
        Section(header: Text("Account").foregroundStyle(.gray)) {
            NavigationLink(destination: ProfileEditView(profile: profileManager.userProfile!)) {
                Label("Edit profile details", systemImage: "person.text.rectangle.fill")
                    .foregroundStyle(Color.glindaPink)
            }
            .listRowBackground(Color.black.opacity(0.2))
            
            Button(action: onResetPassword) {
                Label("Reset password", systemImage: "key.fill")
                    .foregroundStyle(Color.glindaPink)
            }
            .listRowBackground(Color.black.opacity(0.2))
            
            Button(action: onLogoutTap) {
                Label("Logout", systemImage: "door.right.hand.open")
                    .foregroundStyle(.blue)
            }
            .listRowBackground(Color.black.opacity(0.2))
            
            Button(action: onDeleteTap) {
                HStack {
                    Label("Delete account", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    if deleteInProgress {
                        ProgressView()
                    }
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
            .disabled(deleteInProgress)
        }
    }
}

private struct AboutSection: View {
    let sendFeedback: () -> Void
    
    var body: some View {
        Section(header: Text("About").foregroundStyle(.gray)) {
            Button(action: sendFeedback) {
                Label("Send Feedback", systemImage: "envelope.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))
            
            Button("Rate App") {
                // DO ZROBIENIA W PRZYSZŁOŚCI
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }
}

// MARK: - Alerts as a modifier
private struct SettingsAlerts: ViewModifier {
    @Binding var showingLogoutAlert: Bool
    @Binding var showingDeleteAlert: Bool
    @Binding var showingPasswordAlert: Bool
    @Binding var showingResetWaterAlert: Bool
    @Binding var errorDeleting: Bool
    @Binding var passwordAlertMessage: String
    
    let onLogout: () -> Void
    let onDelete: () -> Void
    let onResetWater: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Confirm Logout", isPresented: $showingLogoutAlert) {
                Button("Logout", role: .destructive) { onLogout() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Are you sure you want to log out?") }
            
            .alert("Confirm Account Deletion", isPresented: $showingDeleteAlert) {
                Button("Delete Permanently", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This will permanently remove all your data (profile, recipes, water logs). This action cannot be undone.") }
            
            .alert("Reset Password", isPresented: $showingPasswordAlert) {
                Button("OK") { }
            } message: { Text(passwordAlertMessage) }
            
            .alert("Reset Water History", isPresented: $showingResetWaterAlert) {
                Button("Reset All", role: .destructive) { onResetWater() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This will delete all your water logs. Are you sure?") }
            
            .alert("Error", isPresented: $errorDeleting) {
                Button("OK", role: .cancel) { }
            } message: { Text("An unexpected error occurred while deleting the account. Please log in again and repeat the action.") }
    }
}
