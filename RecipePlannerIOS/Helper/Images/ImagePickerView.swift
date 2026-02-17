//
//  ImagePickerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.selectedImage = image
            } else if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Pomocniczy Widok 
struct RecipeImageEditorView: View {
    @Binding var selectedImage: UIImage?
    @Binding var originalImageURL: String?
    
    let onTapAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                    Text("Tap to add or edit a photo")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            Image(systemName: "pencil.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
                .background(Circle().fill(.white))
                .padding(8)
        }
        .onTapGesture(perform: onTapAction)
    }
}
