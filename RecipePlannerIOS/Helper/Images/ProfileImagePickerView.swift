//
//  ProfileImagePickerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// ProfileImagePickerView.swift (POPRAWIONY)
import SwiftUI
import PhotosUI
import UIKit

struct ProfileImagePickerView: View {
    // Stan tymczasowy dla PhotosPicker
    @State private var selectedItem: PhotosPickerItem?
    
    // @Binding do nowego, wybranego obrazu UIImage
    @Binding var profileImage: UIImage?
    
    // @Binding do istniejącego URL (NAPRAWIONY BŁĄD)
    @Binding var profileImageURL: String?
    
    // Domyślna ikona, gdy nic nie jest ustawione
    let defaultIcon = Image(systemName: "person.circle.fill")

    var body: some View {
        VStack {
            if let newImage = profileImage {
                Image(uiImage: newImage)
                    .resizable().scaledToFill()
                    .frame(width: 100, height: 100).clipShape(Circle())
                
            } else if let urlString = profileImageURL {
                // Używamy AsyncImageView
                AsyncImageView(urlString: urlString)
                    .scaledToFill()
                    .frame(width: 100, height: 100).clipShape(Circle())
                
            } else {
                // 3. Domyślny widok
                defaultIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.gray.opacity(0.4))
            }
            
            HStack(spacing: 20) {
                // Przycisk zmiany zdjęcia
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Change photo")
                }
                // --- LOGIKA POBIERANIA OBRAZU Z BIBLIOTEKI ---
                .onChange(of: selectedItem) { _, newValue in
                    // Ta akcja jest asynchroniczna, więc wymaga Task
                    Task {
                        // Sprawdzenie i wczytanie danych
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            
                            profileImage = image // Ustawia nowe zdjęcie
                            profileImageURL = nil // Wyczyść stary URL, bo mamy nowy obraz
                            
                            // Możemy zerować selectedItem, ale Task się zakończy,
                            // więc często nie jest to konieczne w tym miejscu.
                            
                        } else {
                            // Jeśli błąd wczytywania, upewnij się, że stan jest czysty
                            selectedItem = nil
                        }
                    }
                }
                
                // Przycisk "Usuń"
                if profileImage != nil || profileImageURL != nil {
                    Button("Delete photo") {
                        // UWAGA: Ustawiamy OBA na nil.
                        // 1. Ustawienie profileImage na nil (usuwa nowe wybrane)
                        profileImage = nil
                        // 2. Ustawienie profileImageURL na nil (sygnalizuje, że istniejący ma być usunięty/pominięty)
                        profileImageURL = nil
                    }
                    .tint(.red)
                }
            }
        }
        .padding(.vertical)
    }
}
