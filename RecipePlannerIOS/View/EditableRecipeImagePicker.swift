//
//  EditableRecipeImagePicker.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 18/11/2025.
//

import SwiftUI
import UIKit

struct EditableRecipeImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Binding var originalImageURL: String?

    private let imageHeight: CGFloat = 220
    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            // 1) If user picked an image in this session
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                    .clipped()
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            }
            // 2) Else try to load remote image from originalImageURL
            else if let urlString = originalImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                            .clipped()
                            .cornerRadius(cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            }
            // 3) Else show placeholder
            else {
                placeholderView
            }

            // Subtle camera hint overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Label("Tap to change", systemImage: "camera.fill")
                        .font(.footnote)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .animation(.default, value: selectedImage)
        .animation(.default, value: originalImageURL)
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.08))
                .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Tap to add a photo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
