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
            
            NativeTextView(text: $instruction)
                .frame(minHeight: 80)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            
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
                    .buttonStyle(.borderless)
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
        ForEach(sections) { section in
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(section.instructions.indices, id: \.self) { instructionIndex in
                    InstructionRowEditor(
                        index: instructionIndex + 1,
                        instruction: instructionBinding(sectionID: section.id, instructionIndex: instructionIndex),
                        onDelete: {
                            deleteInstruction(sectionID: section.id, at: instructionIndex)
                        }
                    )
                }
                .onMove { indices, newOffset in
                    moveInstructions(in: section.id, from: indices, to: newOffset)
                }
                
                Button(action: {
                    withAnimation {
                        appendInstruction(to: section.id)
                    }
                }) {
                    HStack {
                        Spacer()
                        Label("Add Step", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.wickedGreen)
                .padding(.vertical, 8)
                
            } label: {
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundColor(Color.wickedGreen)
                    let sectionTitle = title(for: section.id)
                    if sectionTitle.isEmpty {
                        Text("Untitled Section")
                            .bold()
                            .foregroundStyle(Color.white)
                    } else {
                        Text(sectionTitle)
                            .bold()
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .listRowBackground(Color.black.opacity(0.2))
        }
    }

    private func title(for sectionID: UUID) -> String {
        sections.first(where: { $0.id == sectionID })?.title ?? ""
    }

    private func appendInstruction(to sectionID: UUID) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[sectionIndex].instructions.append("")
    }

    private func moveInstructions(in sectionID: UUID, from indices: IndexSet, to newOffset: Int) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[sectionIndex].instructions.move(fromOffsets: indices, toOffset: newOffset)
    }

    private func deleteInstruction(sectionID: UUID, at index: Int) {
        withAnimation {
            guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return }
            if sections[sectionIndex].instructions.indices.contains(index) {
                sections[sectionIndex].instructions.remove(at: index)
            }
        }
    }

    private func instructionBinding(sectionID: UUID, instructionIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }),
                      sections[sectionIndex].instructions.indices.contains(instructionIndex) else {
                    return ""
                }
                return sections[sectionIndex].instructions[instructionIndex]
            },
            set: { newValue in
                guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }),
                      sections[sectionIndex].instructions.indices.contains(instructionIndex) else { return }
                sections[sectionIndex].instructions[instructionIndex] = newValue
            }
        )
    }
}

private struct FlatInstructionsContent: View {
    @Binding var instructions: [String]

    var body: some View {
        let enumerated = Array(instructions.enumerated())
        
        ForEach(enumerated, id: \.offset) { index, _ in
            InstructionRowEditor(
                index: index + 1,
                instruction: instructionBinding(at: index),
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
        .buttonStyle(.borderless)
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

    private func instructionBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                instructions.indices.contains(index) ? instructions[index] : ""
            },
            set: { newValue in
                guard instructions.indices.contains(index) else { return }
                instructions[index] = newValue
            }
        )
    }
}
