//
//  DietMultiSelectView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// DietMultiSelectView.swift

import SwiftUI

struct DietMultiSelectView: View {
    @Binding var selectedDiets: [String]
    
    var body: some View {
        ForEach(Constants.dietOptions, id: \.self) { diet in
            HStack {
                Text(diet)
                Spacer()
                // Jeśli dieta jest w tablicy, pokazujemy zaznaczenie
                if selectedDiets.contains(diet) {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle()) // Ważne: Sprawia, że cały wiersz jest dotykalny
            .onTapGesture {
                toggleSelection(diet)
            }
        }
    }
    
    private func toggleSelection(_ diet: String) {
        if let index = selectedDiets.firstIndex(of: diet) {
            selectedDiets.remove(at: index) // Odznacz
        } else {
            selectedDiets.append(diet) // Zaznacz
        }
    }
}
