//
//  CustomLoadingView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 27/11/2025.
//

import SwiftUI

/// Niestandardowy widok ładowania z tłem obrazu.
struct CustomLoadingView: View {
    let imageName: String 
    
    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
