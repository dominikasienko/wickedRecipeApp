//
//  InstructionsSection.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/12/2025.
//

import SwiftUI

private struct InstructionRowEditor: View {
    let index: Int
    @Binding var instruction: String
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index).")
                .bold()
                .foregroundStyle(Color.gray)
                .padding(.top, 12)
                .frame(width: 25)
            
            TextEditor(text: $instruction)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .foregroundStyle(Color.white)
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(.top, 12)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .listRowBackground(Color.black.opacity(0.2))
        .padding(.vertical, 4)
    }
}

struct InstructionsSection: View {
    @Binding var sections: [RecipeSection]
    @Binding var useSections: Bool

    var body: some View {
        Section("Instructions") {
            if useSections {
                SectionalInstructionsContent(sections: $sections)
            } else {
                if !sections.isEmpty {
                    FlatInstructionsContent(instructions: $sections[0].instructions)
                } else {
                    Button("Add first step") {
                        sections = [RecipeSection(title: "", ingredients: [], instructions: [""])]
                    }
                    .foregroundStyle(Color.wickedGreen)
                    .listRowBackground(Color.black.opacity(0.2))
                }
            }
        }
        .headerProminence(.increased)
        .listRowSeparatorTint(Color.white.opacity(0.3))
    }
}

private struct SectionalInstructionsContent: View {
    @Binding var sections: [RecipeSection]

    var body: some View {
        ForEach(sections.indices, id: \.self) { sectionIndex in
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(sections[sectionIndex].instructions.indices, id: \.self) { instructionIndex in
                    InstructionRowEditor(
                        index: instructionIndex + 1,
                        instruction: $sections[sectionIndex].instructions[instructionIndex],
                        onDelete: {
                            deleteInstruction(sectionIndex: sectionIndex, at: instructionIndex)
                        }
                    )
                }
                .onMove { indices, newOffset in
                    sections[sectionIndex].instructions.move(fromOffsets: indices, toOffset: newOffset)
                }
                
                Button(action: {
                    withAnimation {
                        sections[sectionIndex].instructions.append("")
                    }
                }) {
                    HStack {
                        Spacer()
                        Label("Add Step", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .foregroundStyle(Color.wickedGreen)
                .padding(.vertical, 8)
                
            } label: {
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundColor(Color.wickedGreen)
                    Text(sections[sectionIndex].title.isEmpty ? "Untitled Section" : sections[sectionIndex].title)
                        .bold()
                        .foregroundStyle(Color.white)
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private func deleteInstruction(sectionIndex: Int, at index: Int) {
        withAnimation {
            if sections.indices.contains(sectionIndex),
               sections[sectionIndex].instructions.indices.contains(index) {
                sections[sectionIndex].instructions.remove(at: index)
            }
        }
    }
}

private struct FlatInstructionsContent: View {
    @Binding var instructions: [String]

    var body: some View {
        let enumerated = Array(instructions.enumerated())
        
        ForEach(enumerated, id: \.offset) { index, _ in
            InstructionRowEditor(
                index: index + 1,
                instruction: Binding(
                    get: { instructions[index] },
                    set: { instructions[index] = $0 }
                ),
                onDelete: {
                    deleteInstruction(at: index)
                }
            )
        }
        .onMove { indices, newOffset in
            instructions.move(fromOffsets: indices, toOffset: newOffset)
        }
        
        Button(action: {
            withAnimation {
                instructions.append("")
            }
        }) {
            HStack {
                Spacer()
                Label("Add Step", systemImage: "plus.circle.fill")
                    .font(.headline)
                Spacer()
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundStyle(Color.wickedGreen)
        .listRowBackground(Color.black.opacity(0.2))
        .padding(.vertical, 8)
    }
    
    private func deleteInstruction(at index: Int) {
        withAnimation {
            if instructions.indices.contains(index) {
                instructions.remove(at: index)
            }
        }
    }
}
