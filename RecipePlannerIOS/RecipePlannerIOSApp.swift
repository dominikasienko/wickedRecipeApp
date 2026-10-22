import SwiftUI
import FirebaseCore 
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    
    weak var authManager: AuthManager?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase has been successfully configured.")
        
        authManager?.setupAuthStateListener()
        
        return true
    }
}

@main
struct RecipePlannerIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var authManager = AuthManager()
    @State private var profileManager = ProfileManager()
    @State private var storageManager = StorageManager()
    @State private var recipeManager = RecipeManager()
    @State private var waterManager: WaterManager?
    @State private var mealPlanManager: MealPlannerManager?
    @State private var notificationManager = NotificationManager()
    @AppStorage("appLanguagePreference") private var appLanguagePreferenceRaw: String = "system"

    
    init() {
        delegate.authManager = authManager
    }
    
    private var appLocale: Locale {
        if appLanguagePreferenceRaw == "system" {
            return Locale.autoupdatingCurrent
        }

        guard AppLocalization.supportedLanguageIdentifiers.contains(appLanguagePreferenceRaw) else {
            return Locale.autoupdatingCurrent
        }

        return Locale(identifier: appLanguagePreferenceRaw)
    }
    
    var body: some Scene {
        WindowGroup {
            AuthView()
                .environment(authManager)
                .environment(profileManager)
                .environment(storageManager)
                .environment(recipeManager)
                .environment(waterManager)
                .environment(mealPlanManager)
                .environment(notificationManager)
                .environment(\.locale, appLocale)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    _ = Auth.auth().canHandle(url)
                }
        }
    }
}
