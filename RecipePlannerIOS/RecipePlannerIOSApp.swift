import SwiftUI
import FirebaseCore 

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

    
    init() {
        delegate.authManager = authManager
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
        }
    }
}
