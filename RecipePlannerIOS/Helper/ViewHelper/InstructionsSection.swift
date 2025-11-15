//
//  InstructionsSection.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

// InstructionsSection.swift 
import SwiftUI

struct InstructionsSection: View {
    @Binding var instructions: [String]
    
    var body: some View {
        Section("Instructions") {
            // Używamy .indices, aby móc modyfikować elementy (instrukcje[index])
            ForEach($instructions.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .bold()
                        .padding(.top, 8)
                        .frame(width: 25)
                    
                    // Użycie TextEditor jest w porządku, ale upewnijmy się, że ma wystarczającą wysokość
                    TextEditor(text: $instructions[index])
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .onDelete(perform: deleteInstruction)
            
            Button("Add step") {
                instructions.append("")
            }
        }
    }
    
    private func deleteInstruction(offsets: IndexSet) {
        instructions.remove(atOffsets: offsets)
    }
}
