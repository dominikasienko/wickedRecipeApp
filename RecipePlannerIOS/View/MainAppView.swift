//
//  MainAppView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import FirebaseAuth

struct MainAppView: View {
    @Environment(\.locale) private var locale
    @Environment(AuthManager.self) private var authManager
    
    var body: some View {
        VStack(spacing: 20) {
            let greetingName = authManager.user?.email ?? AppLocalization.resolved("User", locale: locale)
            Text("Hello, \(greetingName)!")
                .font(.title)
            
            Button("Log out") {
                do {
                    try authManager.signOut()
                } catch {
                    print("Logout error: \(error.localizedDescription)")
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            
        }
    }
}
