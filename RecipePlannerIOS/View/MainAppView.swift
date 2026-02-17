//
//  MainAppView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import FirebaseAuth

struct MainAppView: View {
    @Environment(AuthManager.self) private var authManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, \(authManager.user?.email ?? "user")!")
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
            
            Button("Delete account") {
                Task {
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        print("Account deletion error: \(error.localizedDescription)")
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}
