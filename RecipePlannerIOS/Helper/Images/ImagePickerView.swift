//
//  ImagePickerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// ImagePickerView.swift
import SwiftUI
import UIKit

// Struktura opakowująca natywny kontroler wyboru obrazu
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator // Ustawienie koordynatora do obsługi zdarzeń
        picker.allowsEditing = true // Pozwól użytkownikowi edytować/kadrować zdjęcie
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Koordynator to klasa pomostowa obsługująca delegaty UIImagePickerController
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        // Metoda wywoływana po wybraniu zdjęcia
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.selectedImage = image
            } else if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false // Zamknij widok po wybraniu zdjęcia
        }

        // Metoda wywoływana, gdy użytkownik anuluje
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Pomocniczy Widok Edycji Zdjęcia
struct RecipeImageEditorView: View {
    // Te zmienne stanu będą powiązane z RecipeImagePickerView
    @Binding var selectedImage: UIImage?
    @Binding var originalImageURL: String?
    
    // Akcja wywoływana, gdy użytkownik chce otworzyć picker
    let onTapAction: () -> Void

    var body: some View {
        // Używamy ZStack do umieszczenia ikony edycji na wierzchu
        ZStack(alignment: .bottomTrailing) {
            // Logika podglądu (URL > UIImage > Placeholder)
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
            } else if let urlString = originalImageURL {
                AsyncImageView(urlString: urlString)
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
            } else {
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                    Text("Dotknij, aby dodać lub edytować zdjęcie")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Ikona edycji na dole/prawej
            Image(systemName: "pencil.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
                .background(Circle().fill(.white))
                .padding(8)
        }
        .onTapGesture(perform: onTapAction)
    }
}
