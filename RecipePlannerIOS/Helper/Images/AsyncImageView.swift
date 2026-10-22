//
//  AsyncImageView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import SwiftUI
import UIKit

struct AsyncImageView: View {
    let urlString: String
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                Color.gray.opacity(0.1)
                    .overlay(ProgressView())
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            await MainActor.run {
                if let loadedImage = UIImage(data: data) {
                    self.image = loadedImage
                }
                self.isLoading = false
            }
        } catch {
            print("AsyncImageView: Image request failed.")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
