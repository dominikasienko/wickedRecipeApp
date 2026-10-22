//
//  ProfileImagePickerView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileImagePickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageLoadRequestID = UUID()
    
    @Binding var profileImage: UIImage?
    @Binding var profileImageURL: String?
    var onImageSelected: () -> Void = {}
    var onImageRemoved: () -> Void = {}
    
    let defaultIcon = Image(systemName: "person.circle.fill")

    var body: some View {
        VStack {
            if let newImage = profileImage {
                Image(uiImage: newImage)
                    .resizable().scaledToFill()
                    .frame(width: 100, height: 100).clipShape(Circle())
            } else if let urlString = profileImageURL {
                AsyncImageView(urlString: urlString)
                    .scaledToFill()
                    .frame(width: 100, height: 100).clipShape(Circle())
            } else {
                defaultIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.gray.opacity(0.4))
            }
            
            HStack(spacing: 20) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Change photo")
                }
                .onChange(of: selectedItem) { _, newValue in
                    guard let newValue else { return }
                    let requestID = UUID()
                    imageLoadRequestID = requestID
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            guard imageLoadRequestID == requestID else { return }
                            profileImage = image
                            profileImageURL = nil
                            onImageSelected()
                        } else {
                            guard imageLoadRequestID == requestID else { return }
                            selectedItem = nil
                        }
                    }
                }
                
                if profileImage != nil || profileImageURL != nil {
                    Button("Delete photo") {
                        profileImage = nil
                        profileImageURL = nil
                        selectedItem = nil
                        imageLoadRequestID = UUID()
                        onImageRemoved()
                    }
                    .tint(.red)
                }
            }
        }
        .padding(.vertical)
    }
}
