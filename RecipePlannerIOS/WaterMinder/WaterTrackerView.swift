import SwiftUI

enum WickedCharacter: String, CaseIterable, Identifiable {
    case elphaba = "Elphaba"
    case glinda = "Glinda"
    case fiyero = "Fiyero"

    var id: String { rawValue }
    
    var assetName: String {
        switch self {
        case .elphaba: return "Elphaba"
        case .glinda: return "Glinda"
        case .fiyero: return "Fiyero"
        }
    }
    
    var waterColor: Color {
        switch self {
        case .elphaba: return Color.wickedGreen
        case .glinda: return Color.glindaPink
        case .fiyero: return Color.wickedBlue
        }
    }
}

// MARK: Dynamiczny widok śledzenia z postacią wypełnianą płynem
struct WickedCharacterTracker: View {
    let character: WickedCharacter
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(character.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .foregroundStyle(.white.opacity(0.3))
                
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(character.waterColor)
                        .frame(height: geometry.size.height * progress)
                }
                .mask {
                    Image(character.assetName)
                        .resizable()
                        .scaledToFit()
                }
                
                Image(character.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .foregroundStyle(.white)
                    .blendMode(.overlay)
                    .opacity(0.1)
            }
        }
    }
}

private struct WickedBackgroundView: View {
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            Ellipse()
                .fill(Color.glindaPink.opacity(0.4))
                .frame(width: 300, height: 300)
                .position(x: 350, y: 50)
                .blur(radius: 100)
                .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.3))
                .frame(width: 200, height: 200)
                .position(x: 50, y: 800)
                .blur(radius: 80)
                .ignoresSafeArea()
        }
    }
}

private struct GoalGlassCard: View {
    let current: Double
    let goal: Double
    let progress: Double
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Target: \(Int(current)) ml / \(Int(goal)) ml")
                .font(.title3).bold()
                .foregroundStyle(.white)
            
            Text(progress >= 1.0 ? "Target Achieved!" : "Keep Drinking!")
                .font(.subheadline)
                .foregroundStyle(progress >= 1.0 ? Color.wickedGreen : Color.glindaPink)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

private struct QuickAddButtonsRow: View {
    let sizes: [Double]
    let tint: Color
    let onAdd: (Double) -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(sizes, id: \.self) { size in
                Button {
                    onAdd(size)
                } label: {
                    Text("+\(Int(size)) ml")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
            }
            
            Button {
                onReset()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.7))
        }
        .padding(.horizontal)
        .padding(.top, 5)
    }
}

struct WaterTrackerView: View {
    @Environment(WaterManager.self) private var waterManager
    
    @AppStorage("selectedWickedCharacter") private var selectedCharacterRaw: String = WickedCharacter.glinda.rawValue
    private var selectedCharacter: WickedCharacter {
        get { WickedCharacter(rawValue: selectedCharacterRaw) ?? .glinda }
        set { selectedCharacterRaw = newValue.rawValue }
    }

    let drinkSizes: [Double] = [250, 500, 750]

    var body: some View {
        NavigationStack {
            ZStack {
                WickedBackgroundView()
                
                VStack(spacing: 20) {
                    if let goal = waterManager.goal {
                        let rawProgress = goal.dailyGoalMl > 0 ? goal.currentIntakeMl / goal.dailyGoalMl : 0.0
                        let progress = min(max(rawProgress, 0.0), 1.0)
                        
                        WickedCharacterTracker(character: selectedCharacter, progress: progress)
                            .frame(height: 350)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                        
                        GoalGlassCard(current: goal.currentIntakeMl, goal: goal.dailyGoalMl, progress: progress)
                        
                        QuickAddButtonsRow(
                            sizes: drinkSizes,
                            tint: selectedCharacter.waterColor,
                            onAdd: { size in
                                Task { try? await waterManager.addLog(amountMl: size) }
                            },
                            onReset: {
                                waterManager.resetTodayIntake()
                            }
                        )
                        
                        Spacer()
                        
                        if let lastLog = waterManager.todayEntries.first {
                            Text("Last drink: \(Int(lastLog.amountMl)) ml at \(lastLog.timestamp, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ContentUnavailableView("Loading profile data...", systemImage: "drop.fill")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.darkBackground.opacity(0.5), for: .navigationBar)
            .navigationTitle("Hydration Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker(
                            "Select Character",
                            selection: Binding<String>(
                                get: { selectedCharacterRaw },
                                set: { newRaw in
                                    selectedCharacterRaw = newRaw
                                }
                            )
                        ) {
                            ForEach(WickedCharacter.allCases) { character in
                                Text(character.rawValue).tag(character.rawValue)
                            }
                        }
                    } label: {
                        Label("Character", systemImage: "wand.and.stars")
                            .foregroundStyle(Color.glindaPink)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WaterHistoryView()
                    } label: {
                        Label("History", systemImage: "list.bullet.clipboard.fill")
                            .foregroundStyle(Color.wickedGreen)
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
