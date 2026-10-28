//
//  SettingsView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 20/11/2025.
//

import SwiftUI
import Observation
import FirebaseAuth
import UniformTypeIdentifiers

enum WeightUnitPreference: String, CaseIterable, Identifiable {
    case kilograms = "kg"
    case pounds = "lb"
    
    var id: String { rawValue }
}

enum HeightUnitPreference: String, CaseIterable, Identifiable {
    case centimeters = "cm"
    case feetInches = "ft + in"
    
    var id: String { rawValue }
}

enum VolumeUnitPreference: String, CaseIterable, Identifiable {
    case milliliters = "ml"
    case ounces = "oz"
    
    var id: String { rawValue }
}

enum EnergyUnitPreference: String, CaseIterable, Identifiable {
    case kilocalories = "kcal"
    case kilojoules = "kJ"
    
    var id: String { rawValue }
}

enum ClockFormatPreference: String, CaseIterable, Identifiable {
    case system = "System"
    case twentyFourHour = "24-hour"
    case twelveHour = "12-hour"
    
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .twentyFourHour: return "24-hour"
        case .twelveHour: return "12-hour"
        }
    }
}

enum WeekStartPreference: Int, CaseIterable, Identifiable {
    case monday = 2
    case sunday = 1
    case saturday = 7
    
    var id: Int { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .monday: return "Monday"
        case .sunday: return "Sunday"
        case .saturday: return "Saturday"
        }
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case de = "de"
    case es = "es"
    case fr = "fr"
    case it = "it"
    case pl = "pl"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .pl: return "Polski"
        }
    }
}

enum ReminderInterval: Int, CaseIterable, Identifiable {
    case every2h = 2
    case every3h = 3
    case every4h = 4
    case every6h = 6
    
    var id: Int { rawValue }
    
    var title: LocalizedStringKey {
        LocalizedStringKey("Every \(rawValue)h")
    }
}

struct SettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(RecipeManager.self) private var recipeManager
    @Environment(StorageManager.self) private var storageManager
    @Environment(WaterManager.self) private var waterManager
    @Environment(MealPlannerManager.self) private var mealPlannerManager
    @Environment(ShoppingListManager.self) private var shoppingListManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.openURL) private var openURL

    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingConsentWithdrawalAlert = false
    @State private var deleteInProgress = false
    @State private var errorDeleting = false
    @State private var deletePassword = ""
    @State private var deletionErrorMessage: LocalizedStringKey = "Account deletion failed. Please try again or contact support."
    
    @State private var showingPasswordAlert = false
    @State private var passwordAlertMessage: LocalizedStringKey = "An unknown error occurred."
    @State private var showingResetWaterAlert = false
    @State private var showingResetMealPlanAlert = false
    @State private var showingClearShoppingListAlert = false
    @State private var showingExportWarning = false
    
    @State private var isShowingExportSheet = false
    @State private var exportDocument = SettingsExportDocument(jsonData: Data())
    @State private var exportFilename = "RecipePlannerIOS-Export"
    @State private var exportErrorMessage: LocalizedStringKey?
    
    @State private var isRefreshingSync = false

    @AppStorage("waterReminderEnabled") private var waterReminderEnabled: Bool = false
    @AppStorage("waterReminderIntervalHours") private var waterReminderIntervalHours: Int = ReminderInterval.every4h.rawValue
    @AppStorage("waterReminderQuietHoursEnabled") private var waterReminderQuietHoursEnabled: Bool = false
    @AppStorage("waterReminderQuietStartHour") private var waterReminderQuietStartHour: Int = 22
    @AppStorage("waterReminderQuietEndHour") private var waterReminderQuietEndHour: Int = 7
    
    @AppStorage("weightUnitPreference") private var weightUnitPreferenceRaw: String = WeightUnitPreference.kilograms.rawValue
    @AppStorage("heightUnitPreference") private var heightUnitPreferenceRaw: String = HeightUnitPreference.centimeters.rawValue
    @AppStorage("volumeUnitPreference") private var volumeUnitPreferenceRaw: String = VolumeUnitPreference.milliliters.rawValue
    @AppStorage("energyUnitPreference") private var energyUnitPreferenceRaw: String = EnergyUnitPreference.kilocalories.rawValue
    @AppStorage("clockFormatPreference") private var clockFormatPreferenceRaw: String = ClockFormatPreference.system.rawValue
    
    @AppStorage("weekStartDay") private var weekStartDay: Int = WeekStartPreference.monday.rawValue
    @AppStorage("defaultMealType") private var defaultMealType: String = "breakfast"
    @AppStorage("shoppingIncludeManualItems") private var shoppingIncludeManualItems: Bool = true
    @AppStorage("shoppingPreserveCompletedState") private var shoppingPreserveCompletedState: Bool = true
    
    @AppStorage("hydrationDefaultDrinkTypeRaw") private var hydrationDefaultDrinkTypeRaw: String = HydrationDrinkType.water.rawValue
    @AppStorage("hydrationDefaultVolumeMl") private var hydrationDefaultVolumeMl: Double = 250
    @AppStorage("hydrationPreferredMilkRaw") private var hydrationPreferredMilkRaw: String = MilkChoice.regular.rawValue
    @AppStorage("hydrationFavoriteDrinkIDs") private var hydrationFavoriteDrinkIDsRaw: String = "water"
    
    @AppStorage("highContrastMode") private var highContrastMode: Bool = false
    @AppStorage("reduceMotionEnabled") private var reduceMotionEnabled: Bool = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("appLanguagePreference") private var appLanguagePreferenceRaw: String = AppLanguagePreference.system.rawValue
    
    @AppStorage("syncLastRefreshEpoch") private var syncLastRefreshEpoch: Double = 0

    private var weightUnitPreference: WeightUnitPreference {
        get { WeightUnitPreference(rawValue: weightUnitPreferenceRaw) ?? .kilograms }
        nonmutating set { weightUnitPreferenceRaw = newValue.rawValue }
    }
    
    private var heightUnitPreference: HeightUnitPreference {
        get { HeightUnitPreference(rawValue: heightUnitPreferenceRaw) ?? .centimeters }
        nonmutating set { heightUnitPreferenceRaw = newValue.rawValue }
    }
    
    private var volumeUnitPreference: VolumeUnitPreference {
        get { VolumeUnitPreference(rawValue: volumeUnitPreferenceRaw) ?? .milliliters }
        nonmutating set { volumeUnitPreferenceRaw = newValue.rawValue }
    }
    
    private var energyUnitPreference: EnergyUnitPreference {
        get { EnergyUnitPreference(rawValue: energyUnitPreferenceRaw) ?? .kilocalories }
        nonmutating set { energyUnitPreferenceRaw = newValue.rawValue }
    }
    
    private var clockFormatPreference: ClockFormatPreference {
        get { ClockFormatPreference(rawValue: clockFormatPreferenceRaw) ?? .system }
        nonmutating set { clockFormatPreferenceRaw = newValue.rawValue }
    }
    
    private var appLanguagePreference: AppLanguagePreference {
        get { AppLanguagePreference(rawValue: appLanguagePreferenceRaw) ?? .system }
        nonmutating set { appLanguagePreferenceRaw = newValue.rawValue }
    }
    
    private var currentWeekStartPreference: WeekStartPreference {
        get { WeekStartPreference(rawValue: weekStartDay) ?? .monday }
        nonmutating set { weekStartDay = newValue.rawValue }
    }
    
    private var selectedReminderInterval: ReminderInterval {
        get { ReminderInterval(rawValue: waterReminderIntervalHours) ?? .every4h }
        nonmutating set { waterReminderIntervalHours = newValue.rawValue }
    }

    private var hydrationFavoriteDrinkSet: Set<String> {
        get {
            Set(
                hydrationFavoriteDrinkIDsRaw
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }
        nonmutating set {
            hydrationFavoriteDrinkIDsRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    private var hydrationDefaultDrinkType: HydrationDrinkType {
        get { HydrationDrinkType(rawValue: hydrationDefaultDrinkTypeRaw) ?? .water }
        nonmutating set { hydrationDefaultDrinkTypeRaw = newValue.rawValue }
    }
    
    private var hydrationPreferredMilk: MilkChoice {
        get { MilkChoice(rawValue: hydrationPreferredMilkRaw) ?? .regular }
        nonmutating set { hydrationPreferredMilkRaw = newValue.rawValue }
    }
    
    private var syncLastRefreshDate: Date? {
        guard syncLastRefreshEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: syncLastRefreshEpoch)
    }

    private func quietHourLabel(_ hour: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = 0

        let date = calendar.date(from: components) ?? Date(timeIntervalSince1970: TimeInterval(hour * 3600))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none

        switch clockFormatPreference {
        case .system:
            formatter.timeStyle = .short
        case .twentyFourHour:
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "HHmm", options: 0, locale: locale) ?? "HH:mm"
        case .twelveHour:
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hmma", options: 0, locale: locale) ?? "h:mm a"
        }

        return formatter.string(from: date)
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            settingsScreenObserved
        }
    }
    
    private var settingsScreenBase: some View {
        ZStack {
            WickedGlassBackground()
            content
        }
        .navigationTitle("Settings")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.darkBackground.opacity(0.5), for: .navigationBar)
        .preferredColorScheme(.dark)
        .contrast(highContrastMode ? 1.12 : 1.0)
        .saturation(highContrastMode ? 1.06 : 1.0)
        .transaction { transaction in
            if reduceMotionEnabled {
                transaction.animation = nil
            }
        }
    }
    
    private var settingsScreenWithAlertsAndExport: some View {
        settingsScreenBase
            .modifier(settingsAlertsModifier)
            .fileExporter(
                isPresented: $isShowingExportSheet,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure = result {
                    exportErrorMessage = AppLocalization.key("Unable to prepare export data.")
                }
            }
            .alert("Export Error", isPresented: exportErrorBinding) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? AppLocalization.key( "Unknown export error"))
            }
    }
    
    private var settingsScreenObserved: some View {
        settingsScreenWithAlertsAndExport
            .onAppear {
                normalizeDefaultMealType()
                if waterReminderEnabled {
                    applyReminderSettings()
                }
            }
            .onChange(of: waterReminderEnabled) { _, _ in
                applyReminderSettings()
            }
            .onChange(of: waterReminderIntervalHours) { _, _ in
                if waterReminderEnabled { applyReminderSettings() }
            }
            .onChange(of: waterReminderQuietHoursEnabled) { _, _ in
                if waterReminderEnabled { applyReminderSettings() }
            }
            .onChange(of: waterReminderQuietStartHour) { _, _ in
                if waterReminderEnabled { applyReminderSettings() }
            }
            .onChange(of: waterReminderQuietEndHour) { _, _ in
                if waterReminderEnabled { applyReminderSettings() }
            }
            .onChange(of: locale.identifier) { _, _ in
                if waterReminderEnabled { applyReminderSettings() }
            }
            .onChange(of: hydrationDefaultDrinkTypeRaw) { _, newValue in
                guard let type = HydrationDrinkType(rawValue: newValue) else { return }
                if !type.volumeOptions.contains(hydrationDefaultVolumeMl) {
                    hydrationDefaultVolumeMl = type.volumeOptions.first ?? hydrationDefaultVolumeMl
                }
            }
    }
    
    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func normalizeDefaultMealType() {
        let normalized = AppOptionCatalog.canonicalValue(
            for: defaultMealType,
            in: AppOptionCatalog.mealTypes
        )
        defaultMealType = AppOptionCatalog.contains(normalized, in: AppOptionCatalog.mealTypes)
            ? normalized
            : "breakfast"
    }
    
    private var settingsAlertsModifier: SettingsAlerts {
        SettingsAlerts(
            showingLogoutAlert: $showingLogoutAlert,
            showingDeleteAlert: $showingDeleteAlert,
            showingConsentWithdrawalAlert: $showingConsentWithdrawalAlert,
            showingPasswordAlert: $showingPasswordAlert,
            showingResetWaterAlert: $showingResetWaterAlert,
            showingResetMealPlanAlert: $showingResetMealPlanAlert,
            showingClearShoppingListAlert: $showingClearShoppingListAlert,
            showingExportWarning: $showingExportWarning,
            errorDeleting: $errorDeleting,
            passwordAlertMessage: $passwordAlertMessage,
            deletePassword: $deletePassword,
            deletionErrorMessage: $deletionErrorMessage,
            requiresPasswordForDeletion: authManager.usesPasswordProvider,
            onLogout: handleLogout,
            onDelete: { password in Task { await handleDeleteAccount(password: password) } },
            onWithdrawConsent: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showingDeleteAlert = true
                }
            },
            onResetWater: { Task { await resetWaterHistory() } },
            onResetMealPlan: { Task { await resetMealPlanHistory() } },
            onClearShoppingList: { shoppingListManager.clearAll() },
            onExport: { exportAppData() }
        )
    }

    @ViewBuilder
    private var content: some View {
        if let profile = profileManager.userProfile {
            List {
                personalizationSection
                unitsAndFormatSection
                healthAndGoalsSection(profile: profile)
                hydrationPreferencesSection
                mealPlanningPreferencesSection
                notificationsSection
                syncSection
                privacyAndSecuritySection
                dataControlsSection
                accountSection(profile: profile)
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .foregroundStyle(.white)
            .wickedReadableWidth(900)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private var personalizationSection: some View {
        Section(header: Text("Personalization").foregroundStyle(.gray)) {
            Picker("Language", selection: Binding(
                get: { appLanguagePreference },
                set: { appLanguagePreference = $0 }
            )) {
                ForEach(AppLanguagePreference.allCases) { language in
                    if language == .system {
                        Text("System").tag(language)
                    } else {
                        Text(verbatim: language.title).tag(language)
                    }
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Toggle("High contrast mode", isOn: $highContrastMode)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)

            Toggle("Reduce motion", isOn: $reduceMotionEnabled)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)

            Toggle("Enable haptics", isOn: $hapticsEnabled)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)

        }
    }

    private var unitsAndFormatSection: some View {
        Section(header: Text("Units & Format").foregroundStyle(.gray)) {
            Picker("Weight", selection: Binding(
                get: { weightUnitPreference },
                set: { weightUnitPreference = $0 }
            )) {
                ForEach(WeightUnitPreference.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Picker("Height", selection: Binding(
                get: { heightUnitPreference },
                set: { heightUnitPreference = $0 }
            )) {
                ForEach(HeightUnitPreference.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Picker("Volume", selection: Binding(
                get: { volumeUnitPreference },
                set: { volumeUnitPreference = $0 }
            )) {
                ForEach(VolumeUnitPreference.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Picker("Energy", selection: Binding(
                get: { energyUnitPreference },
                set: { energyUnitPreference = $0 }
            )) {
                ForEach(EnergyUnitPreference.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Picker("Time format", selection: Binding(
                get: { clockFormatPreference },
                set: { clockFormatPreference = $0 }
            )) {
                ForEach(ClockFormatPreference.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private func healthAndGoalsSection(profile: UserProfile) -> some View {
        Section(header: Text("Health & Goals").foregroundStyle(.gray)) {
            NavigationLink(destination: ProfileEditView(profile: profile)) {
                Label("Edit health profile", systemImage: "heart.text.square.fill")
                    .foregroundStyle(Color.glindaPink)
            }
            .listRowBackground(Color.black.opacity(0.2))

            HStack {
                Text("Profile completeness")
                Spacer()
                Text(profile.isHealthProfileComplete ? AppLocalization.key( "Complete") : AppLocalization.key( "Incomplete"))
                    .foregroundStyle(profile.isHealthProfileComplete ? Color.wickedGreen : .orange)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Text(AppLocalization.key("Complete your profile and enable general estimates to see reference ranges."))
                .font(.caption)
                .foregroundStyle(.gray)
                .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private var hydrationPreferencesSection: some View {
        Section(header: Text("Hydration Preferences").foregroundStyle(.gray)) {
            Picker("Default drink", selection: Binding(
                get: { hydrationDefaultDrinkType },
                set: { hydrationDefaultDrinkType = $0 }
            )) {
                ForEach(HydrationDrinkType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            let defaultVolumeOptions = hydrationDefaultDrinkType.volumeOptions
            Picker("Default amount", selection: $hydrationDefaultVolumeMl) {
                ForEach(defaultVolumeOptions, id: \.self) { amount in
                    Text("\(Int(amount)) ml").tag(amount)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            if hydrationDefaultDrinkType.supportsMilkChoice {
                Picker("Default milk", selection: Binding(
                    get: { hydrationPreferredMilk },
                    set: { hydrationPreferredMilk = $0 }
                )) {
                    ForEach(MilkChoice.allCases) { milk in
                        Text(milk.displayName).tag(milk)
                    }
                }
                .listRowBackground(Color.black.opacity(0.2))
            }

            ForEach(HydrationDrinkType.allCases) { type in
                Toggle(isOn: Binding(
                    get: { hydrationFavoriteDrinkSet.contains(type.rawValue) },
                    set: { isOn in
                        var current = hydrationFavoriteDrinkSet
                        if isOn {
                            current.insert(type.rawValue)
                        } else {
                            current.remove(type.rawValue)
                        }
                        hydrationFavoriteDrinkSet = current
                    }
                )) {
                    HStack(spacing: 0) {
                        Text("Favorite: ")
                        Text(type.displayName)
                    }
                }
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)
            }
        }
    }

    private var mealPlanningPreferencesSection: some View {
        Section(header: Text("Meal Planning Preferences").foregroundStyle(.gray)) {
            Picker("Default meal slot", selection: $defaultMealType) {
                ForEach(AppOptionCatalog.mealTypes) { meal in
                    Text(meal.title).tag(meal.id)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Picker("Week starts on", selection: Binding(
                get: { currentWeekStartPreference },
                set: { currentWeekStartPreference = $0 }
            )) {
                ForEach(WeekStartPreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Toggle("Include manual shopping items on regenerate", isOn: $shoppingIncludeManualItems)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)

            Toggle("Preserve checked shopping items", isOn: $shoppingPreserveCompletedState)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)
        }
    }

    private var notificationsSection: some View {
        Section(header: Text("Notifications").foregroundStyle(.gray)) {
            Toggle("Water Reminders", isOn: $waterReminderEnabled)
                .listRowBackground(Color.black.opacity(0.2))
                .tint(.wickedGreen)

            if waterReminderEnabled {
                Picker("Reminder interval", selection: Binding(
                    get: { selectedReminderInterval },
                    set: { selectedReminderInterval = $0 }
                )) {
                    ForEach(ReminderInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .listRowBackground(Color.black.opacity(0.2))

                Toggle("Quiet hours", isOn: $waterReminderQuietHoursEnabled)
                    .listRowBackground(Color.black.opacity(0.2))
                    .tint(.wickedGreen)

                if waterReminderQuietHoursEnabled {
                    Picker("Quiet start", selection: $waterReminderQuietStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(quietHourLabel(hour)).tag(hour)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))

                    Picker("Quiet end", selection: $waterReminderQuietEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(quietHourLabel(hour)).tag(hour)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                }
            }
        }
    }

    private var syncSection: some View {
        Section(header: Text("Sync").foregroundStyle(.gray)) {
            HStack {
                Text("Profile")
                Spacer()
                Image(systemName: profileManager.userProfile == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(profileManager.userProfile == nil ? .orange : .wickedGreen)
            }
            .listRowBackground(Color.black.opacity(0.2))

            HStack {
                Text("Recipes")
                Spacer()
                Text("\(recipeManager.userRecipes.count)")
                    .foregroundStyle(.gray)
            }
            .listRowBackground(Color.black.opacity(0.2))

            HStack {
                Text("Water records")
                Spacer()
                Text("\(waterManager.allRecords.count)")
                    .foregroundStyle(.gray)
            }
            .listRowBackground(Color.black.opacity(0.2))

            HStack {
                Text("Meal plan entries")
                Spacer()
                Text("\(mealPlannerManager.allMealPlanEntries.count)")
                    .foregroundStyle(.gray)
            }
            .listRowBackground(Color.black.opacity(0.2))

            HStack {
                Text("Last manual refresh")
                Spacer()
                if let syncLastRefreshDate {
                    Text(syncLastRefreshDate, style: .relative)
                        .foregroundStyle(.gray)
                } else {
                    Text("Never")
                        .foregroundStyle(.gray)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                Task {
                    await refreshSyncData()
                }
            } label: {
                HStack {
                    Label("Refresh now", systemImage: "arrow.clockwise")
                    Spacer()
                    if isRefreshingSync {
                        ProgressView()
                    }
                }
            }
            .disabled(isRefreshingSync)
            .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private var privacyAndSecuritySection: some View {
        Section(header: Text("Privacy & Security").foregroundStyle(.gray)) {
            Button {
                openURL(LegalLinks.privacyPolicy)
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))

            if let healthConsentDate = profileManager.userProfile?.healthDataConsentAt {
                HStack {
                    Label("Health data consent", systemImage: "heart.text.square.fill")
                    Spacer()
                    Text(healthConsentDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .listRowBackground(Color.black.opacity(0.2))

                Button(role: .destructive) {
                    showingConsentWithdrawalAlert = true
                } label: {
                    Label("Withdraw health data consent", systemImage: "hand.raised.slash.fill")
                }
                .listRowBackground(Color.black.opacity(0.2))
            } else {
                Text("No health data consent is recorded for this account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.black.opacity(0.2))
            }

            Button {
                openSettings()
            } label: {
                Label("Open iOS permission settings", systemImage: "gearshape.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))

        }
    }

    private var dataControlsSection: some View {
        Section(header: Text("Data Controls").foregroundStyle(.gray)) {
            Button {
                showingExportWarning = true
            } label: {
                Label("Export my data", systemImage: "square.and.arrow.up")
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                showingResetWaterAlert = true
            } label: {
                Label("Reset all water history", systemImage: "drop.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                showingResetMealPlanAlert = true
            } label: {
                Label("Reset meal plan history", systemImage: "calendar.badge.minus")
                    .foregroundStyle(.orange)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                showingClearShoppingListAlert = true
            } label: {
                Label("Clear shopping list", systemImage: "cart.fill.badge.minus")
                    .foregroundStyle(.orange)
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private func accountSection(profile: UserProfile) -> some View {
        Section(header: Text("Account").foregroundStyle(.gray)) {
            NavigationLink(destination: ProfileEditView(profile: profile)) {
                Label("Edit profile details", systemImage: "person.text.rectangle.fill")
                    .foregroundStyle(Color.glindaPink)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button(action: resetPassword) {
                Label("Reset password", systemImage: "key.fill")
                    .foregroundStyle(Color.glindaPink)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                showingLogoutAlert = true
            } label: {
                Label("Logout", systemImage: "door.right.hand.open")
                    .foregroundStyle(.blue)
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                showingDeleteAlert = true
            } label: {
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

    private var aboutSection: some View {
        Section(header: Text("About").foregroundStyle(.gray)) {
            HStack {
                Label("App Version", systemImage: "info.circle.fill")
                Spacer()
                Text(appVersionLine)
                    .foregroundStyle(.gray)
            }
            .listRowBackground(Color.black.opacity(0.2))

            NavigationLink(destination: ThirdPartyLicensesView()) {
                Label("Third-party SDKs & licenses", systemImage: "books.vertical.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                sendFeedback()
            } label: {
                Label("Send Feedback", systemImage: "envelope.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))

            Button {
                reportBug()
            } label: {
                Label("Report a bug", systemImage: "ladybug.fill")
            }
            .listRowBackground(Color.black.opacity(0.2))

            Text("Calorie and hydration targets are educational estimates, not medical advice.")
                .font(.caption)
                .foregroundStyle(.gray)
                .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private func applyReminderSettings() {
        notificationManager.toggleWaterReminders(
            isOn: waterReminderEnabled,
            intervalHours: waterReminderIntervalHours,
            quietHoursEnabled: waterReminderQuietHoursEnabled,
            quietStartHour: waterReminderQuietStartHour,
            quietEndHour: waterReminderQuietEndHour,
            locale: locale
        )
    }

    private func handleDeleteAccount(password: String) async {
        guard !deleteInProgress else { return }
        deleteInProgress = true
        errorDeleting = false

        do {
            try await authManager.deleteUserAndData(
                password: password.isEmpty ? nil : password,
                profileManager: profileManager,
                recipeManager: recipeManager,
                storageManager: storageManager,
                waterManager: waterManager,
                mealPlannerManager: mealPlannerManager,
                shoppingListManager: shoppingListManager,
                notificationManager: notificationManager
            )
            deletePassword = ""
        } catch let error as AccountDeletionError {
            switch error {
            case .reauthenticationFailed:
                deletionErrorMessage = AppLocalization.key("We couldn't verify your sign-in. No account data was deleted.")
            case .dataCleanupFailed:
                deletionErrorMessage = AppLocalization.key("Some account data could not be removed. Your sign-in account remains active; some data may already have been removed. Retry or contact support.")
            case .authenticationDeletionFailed:
                deletionErrorMessage = AppLocalization.key("Your personal data was removed, but the sign-in account could not be deleted. Please contact support.")
            case .missingUser, .unsupportedSignInProvider:
                deletionErrorMessage = AppLocalization.key("We couldn't verify your account. Please sign in again or contact support.")
            }
            errorDeleting = true
            deleteInProgress = false
        } catch {
            deletionErrorMessage = AppLocalization.key("Account deletion failed. Please try again or contact support.")
            errorDeleting = true
            deleteInProgress = false
        }
    }

    private func handleLogout() {
        do {
            try authManager.signOut()
            shoppingListManager.clearAll()
            notificationManager.cancelAllWaterReminders()
        } catch {
            deletionErrorMessage = AppLocalization.key("We couldn't sign you out. Please try again.")
            errorDeleting = true
        }
    }

    private func refreshSyncData() async {
        guard let userId = authManager.user?.uid else { return }

        isRefreshingSync = true
        defer { isRefreshingSync = false }

        do {
            try await profileManager.fetchUserProfile(userId: userId)
            try await recipeManager.fetchUserRecipes(userId: userId)
            await waterManager.loadHistoricalRecords()
            syncLastRefreshEpoch = Date().timeIntervalSince1970
        } catch {
            print("SettingsView: refresh failed: \(error.localizedDescription)")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func resetPassword() {
        guard let email = authManager.user?.email else {
            passwordAlertMessage = AppLocalization.key( "Could not find your email address.")
            showingPasswordAlert = true
            return
        }

        Task {
            do {
                try await authManager.sendPasswordReset(withEmail: email)
                passwordAlertMessage = AppLocalization.key( "A password reset link has been sent to \(email).")
            } catch {
                passwordAlertMessage = AppLocalization.key("Failed to send reset email.")
            }
            showingPasswordAlert = true
        }
    }

    private func sendFeedback() {
        let email = LegalLinks.contactEmail
        if let url = URL(string: "mailto:\(email)") {
            openURL(url)
        }
    }

    private func reportBug() {
        let email = LegalLinks.contactEmail
        let subject = "RecipePlannerIOS Bug Report"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)") {
            openURL(url)
        }
    }

    private func resetWaterHistory() async {
        do {
            try await waterManager.deleteAllWaterRecords()
        } catch {
            print("SettingsView: Failed to delete water history: \(error.localizedDescription)")
        }
    }

    private func resetMealPlanHistory() async {
        do {
            try await mealPlannerManager.deleteAllMealPlanEntries()
        } catch {
            print("SettingsView: Failed to delete meal plan history: \(error.localizedDescription)")
        }
    }

    private func exportAppData() {
        guard let document = buildExportDocument() else {
            exportErrorMessage = AppLocalization.key( "Unable to prepare export data.")
            return
        }

        exportDocument = document
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        exportFilename = "RecipePlannerIOS-Export-\(formatter.string(from: Date()))"
        isShowingExportSheet = true
    }

    private func buildExportDocument() -> SettingsExportDocument? {
        let settings = ExportSettingsSnapshot(
            weightUnit: weightUnitPreference.rawValue,
            heightUnit: heightUnitPreference.rawValue,
            volumeUnit: volumeUnitPreference.rawValue,
            energyUnit: energyUnitPreference.rawValue,
            clockFormat: clockFormatPreference.rawValue,
            language: appLanguagePreference.rawValue,
            highContrastMode: highContrastMode,
            reduceMotionEnabled: reduceMotionEnabled,
            hapticsEnabled: hapticsEnabled,
            waterRemindersEnabled: waterReminderEnabled,
            waterReminderIntervalHours: waterReminderIntervalHours,
            waterReminderQuietHoursEnabled: waterReminderQuietHoursEnabled,
            waterReminderQuietStartHour: waterReminderQuietStartHour,
            waterReminderQuietEndHour: waterReminderQuietEndHour,
            hydrationDefaultDrinkType: hydrationDefaultDrinkTypeRaw,
            hydrationDefaultVolumeMl: hydrationDefaultVolumeMl,
            hydrationPreferredMilk: hydrationPreferredMilkRaw,
            hydrationFavoriteDrinkIDs: hydrationFavoriteDrinkIDsRaw,
            defaultMealType: defaultMealType,
            weekStartDay: weekStartDay,
            shoppingIncludeManualItems: shoppingIncludeManualItems,
            shoppingPreserveCompletedState: shoppingPreserveCompletedState
        )

        let payload = ExportPayload(
            exportedAt: Date(),
            userEmail: authManager.user?.email,
            profile: profileManager.userProfile,
            recipes: recipeManager.userRecipes,
            waterRecords: waterManager.allRecords,
            mealPlanEntries: mealPlannerManager.allMealPlanEntries,
            shoppingList: shoppingListManager.shoppingList,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload) else { return nil }
        return SettingsExportDocument(jsonData: data)
    }
}

private struct WickedGlassBackground: View {
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            WickedAmbientGlowLayer(pinkOpacity: 0.3, greenOpacity: 0.3)
                .ignoresSafeArea()
        }
    }
}

private struct SettingsAlerts: ViewModifier {
    @Binding var showingLogoutAlert: Bool
    @Binding var showingDeleteAlert: Bool
    @Binding var showingConsentWithdrawalAlert: Bool
    @Binding var showingPasswordAlert: Bool
    @Binding var showingResetWaterAlert: Bool
    @Binding var showingResetMealPlanAlert: Bool
    @Binding var showingClearShoppingListAlert: Bool
    @Binding var showingExportWarning: Bool
    @Binding var errorDeleting: Bool
    @Binding var passwordAlertMessage: LocalizedStringKey
    @Binding var deletePassword: String
    @Binding var deletionErrorMessage: LocalizedStringKey

    let requiresPasswordForDeletion: Bool
    let onLogout: () -> Void
    let onDelete: (String) -> Void
    let onWithdrawConsent: () -> Void
    let onResetWater: () -> Void
    let onResetMealPlan: () -> Void
    let onClearShoppingList: () -> Void
    let onExport: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Confirm Logout", isPresented: $showingLogoutAlert) {
                Button("Logout", role: .destructive) { onLogout() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Confirm Account Deletion", isPresented: $showingDeleteAlert) {
                if requiresPasswordForDeletion {
                    SecureField(AppLocalization.key("Current password"), text: $deletePassword)
                }
                Button("Delete Permanently", role: .destructive) { onDelete(deletePassword) }
                Button("Cancel", role: .cancel) { deletePassword = "" }
            } message: {
                Text(AppLocalization.key("This permanently removes your profile, recipes and photos, hydration history, meal plans and local shopping list. You must verify your sign-in first. This action cannot be undone."))
            }
            .alert(AppLocalization.key("Withdraw health data consent?"), isPresented: $showingConsentWithdrawalAlert) {
                Button(AppLocalization.key("Delete account"), role: .destructive) { onWithdrawConsent() }
                Button(AppLocalization.key("Cancel"), role: .cancel) { }
            } message: {
                Text(AppLocalization.key("In this version, the app needs your health data to work. To withdraw your consent, delete your account. Your data will be removed."))
            }
            .alert("Reset Password", isPresented: $showingPasswordAlert) {
                Button("OK") { }
            } message: {
                Text(passwordAlertMessage)
            }
            .alert("Reset Water History", isPresented: $showingResetWaterAlert) {
                Button("Reset All", role: .destructive) { onResetWater() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all your water logs. Are you sure?")
            }
            .alert("Reset Meal Plan", isPresented: $showingResetMealPlanAlert) {
                Button("Reset All", role: .destructive) { onResetMealPlan() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all your meal plan entries. Are you sure?")
            }
            .alert("Clear Shopping List", isPresented: $showingClearShoppingListAlert) {
                Button("Clear", role: .destructive) { onClearShoppingList() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear all shopping list items. Are you sure?")
            }
            .alert(AppLocalization.key("Export personal data?"), isPresented: $showingExportWarning) {
                Button(AppLocalization.key("Export")) { onExport() }
                Button(AppLocalization.key("Cancel"), role: .cancel) { }
            } message: {
                Text(AppLocalization.key("The file contains your personal and health data. Store it in a safe place."))
            }
            .alert("Error", isPresented: $errorDeleting) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionErrorMessage)
            }
    }
}

private struct SettingsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var jsonData: Data

    init(jsonData: Data) {
        self.jsonData = jsonData
    }

    init(configuration: ReadConfiguration) throws {
        self.jsonData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}

private struct ExportSettingsSnapshot: Codable {
    let weightUnit: String
    let heightUnit: String
    let volumeUnit: String
    let energyUnit: String
    let clockFormat: String
    let language: String
    let highContrastMode: Bool
    let reduceMotionEnabled: Bool
    let hapticsEnabled: Bool
    let waterRemindersEnabled: Bool
    let waterReminderIntervalHours: Int
    let waterReminderQuietHoursEnabled: Bool
    let waterReminderQuietStartHour: Int
    let waterReminderQuietEndHour: Int
    let hydrationDefaultDrinkType: String
    let hydrationDefaultVolumeMl: Double
    let hydrationPreferredMilk: String
    let hydrationFavoriteDrinkIDs: String
    let defaultMealType: String
    let weekStartDay: Int
    let shoppingIncludeManualItems: Bool
    let shoppingPreserveCompletedState: Bool
}

private struct ExportPayload: Codable {
    let exportedAt: Date
    let userEmail: String?
    let profile: UserProfile?
    let recipes: [Recipe]
    let waterRecords: [WaterRecord]
    let mealPlanEntries: [MealPlanEntry]
    let shoppingList: [ShoppingListItem]
    let settings: ExportSettingsSnapshot
}

private struct ThirdPartyLicensesView: View {
    private let dependencies: [(name: String, url: String)] = [
        ("Firebase iOS SDK", "https://github.com/firebase/firebase-ios-sdk"),
        ("SDWebImage", "https://github.com/SDWebImage/SDWebImage"),
        ("SDWebImageSwiftUI", "https://github.com/SDWebImage/SDWebImageSwiftUI"),
        ("OpenFoodFacts Swift", "https://github.com/openfoodfacts/openfoodfacts-swift"),
        ("TOCropViewController", "https://github.com/TimOliver/TOCropViewController"),
        ("BarcodeView", "https://github.com/hrabkin/BarcodeView.git"),
        ("GoogleUtilities", "https://github.com/google/GoogleUtilities.git"),
        ("GoogleDataTransport", "https://github.com/google/GoogleDataTransport.git"),
        ("gRPC Binary", "https://github.com/google/grpc-binary.git"),
        ("GTMSessionFetcher", "https://github.com/google/gtm-session-fetcher.git"),
        ("Swift Protobuf", "https://github.com/apple/swift-protobuf.git")
    ]

    var body: some View {
        List {
            ForEach(dependencies, id: \.name) { item in
                if let url = URL(string: item.url) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .foregroundStyle(.white)
                            Text(item.url)
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.2))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.darkBackground.ignoresSafeArea())
        .navigationTitle("SDK Licenses")
    }
}
