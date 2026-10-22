//
// DietMultiSelectView.swift
// RecipePlannerIOS
//
// Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct DietMultiSelectView: View {
    @Binding var selectedDiets: [String]
    
    private let wickedGreen = Color.wickedGreen
    
    var body: some View {
        List {
            ForEach(AppOptionCatalog.dietOptions) { diet in
                HStack {
                    Text(diet.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    
                    if selectedDiets.contains(diet.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(wickedGreen)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .contentShape(Rectangle()) 
                .onTapGesture {
                    toggleSelection(diet.id)
                }
                
                // MARK: - Row Styling
                .padding(.vertical, 12)
                .padding(.horizontal, 15)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Select Diets")
        .background(
            Color.darkBackground
                .edgesIgnoringSafeArea(.all)
        )
    }
    
    /// Logic to add or remove diet from the binding array
    private func toggleSelection(_ diet: String) {
        if let index = selectedDiets.firstIndex(of: diet) {
            selectedDiets.remove(at: index)
        } else {
            selectedDiets.append(diet)
        }
    }
}
