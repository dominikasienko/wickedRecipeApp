//
//  RecipeImagePicker.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct RecipeImagePicker: View {
    @Binding var selectedImage: UIImage?

    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
            } else {
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                    Text("Add a photo of the recipe")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}
