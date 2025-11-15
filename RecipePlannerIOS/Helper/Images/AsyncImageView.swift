//
//  AsyncImageView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

// AsyncImageView.swift
import SwiftUI
import UIKit

struct AsyncImageView: View {
    let urlString: String
    
    // Stan do przechowywania pobranego obrazu
    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                // Wyświetlanie placeholder'a i wskaźnika ładowania
                Color.gray.opacity(0.1)
                    .overlay(ProgressView())
            } else if let image = image {
                // Wyświetlanie pobranego obrazu
                Image(uiImage: image)
                    .resizable()
            } else {
                // Wyświetlanie domyślnego zdjęcia w przypadku błędu lub braku URL
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .task {
            // Uruchomienie ładowania asynchronicznego
            await loadImage()
        }
    }
    
    // Asynchroniczna funkcja do pobierania obrazu z URL
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
            print("Error loading image from URL: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
