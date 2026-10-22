import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

private struct LiquidWaveShape: Shape {
    var progress: Double
    var phase: Double
    var amplitude: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let baseFillHeight = rect.height * CGFloat(1.0 - clampedProgress)
        let adjustedAmplitude = CGFloat(amplitude) * (0.35 + CGFloat(clampedProgress) * 0.65)
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseFillHeight))
        
        let width = max(rect.width, 1)
        for x in stride(from: 0.0, through: width, by: 1.0) {
            let relativeX = x / width
            let sine = sin((relativeX * .pi * 2.0 * 1.25) + phase)
            let y = baseFillHeight + adjustedAmplitude * CGFloat(sine)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct WickedCharacterTracker: View {
    let character: WickedCharacter
    let progress: Double
    let liquidColor: Color
    let reduceMotion: Bool
    
    @State private var animatedProgress: Double = 0.0
    
    private func clampedProgress(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if reduceMotion {
                trackerContent(in: geometry, phase: 0, waveAmplitude: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    trackerContent(
                        in: geometry,
                        phase: context.date.timeIntervalSinceReferenceDate * 2.2,
                        waveAmplitude: 8
                    )
                }
            }
        }
        .onAppear {
            animatedProgress = clampedProgress(progress)
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.65)) {
                animatedProgress = clampedProgress(newValue)
            }
        }
    }
    
    private func trackerContent(in geometry: GeometryProxy, phase: Double, waveAmplitude: Double) -> some View {
        let fillProgress = clampedProgress(animatedProgress)
        
        return ZStack {
            Image(character.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width)
                .opacity(0.12)
                .saturation(0.25)
            
            if fillProgress > 0 {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(liquidColor.opacity(0.96))
                        .frame(height: geometry.size.height * fillProgress)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    
                    LiquidWaveShape(progress: fillProgress, phase: phase, amplitude: waveAmplitude)
                        .fill(liquidColor)
                    
                    LiquidWaveShape(
                        progress: max(fillProgress - 0.012, 0.0),
                        phase: phase + (.pi / 1.7),
                        amplitude: waveAmplitude * 0.62
                    )
                    .fill(liquidColor.opacity(0.78))
                }
                .mask {
                    Image(character.assetName)
                        .resizable()
                        .scaledToFit()
                }
            }
            
            Image(character.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width)
                .opacity(0.26)
        }
        .animation(.easeInOut(duration: 0.65), value: fillProgress)
    }
}

private struct WickedBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.13),
                    Color(red: 0.07, green: 0.06, blue: 0.12),
                    Color(red: 0.09, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.glindaPink.opacity(0.38))
                .frame(width: 320, height: 320)
                .position(x: 340, y: 70)
                .blur(radius: 110)
                .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.wickedGreen.opacity(0.33))
                .frame(width: 260, height: 260)
                .position(x: 35, y: 780)
                .blur(radius: 95)
                .ignoresSafeArea()
            
            Ellipse()
                .fill(Color.wickedBlue.opacity(0.28))
                .frame(width: 280, height: 280)
                .position(x: 360, y: 720)
                .blur(radius: 115)
                .ignoresSafeArea()
        }
    }
}

private struct GoalGlassCard: View {
    let currentBeverageVolume: Double
    let goal: Double?
    let progress: Double
    
    var body: some View {
        VStack(spacing: 7) {
            Text(AppLocalization.key("Beverages logged: \(Int(currentBeverageVolume)) ml"))
                .font(.headline)
                .foregroundStyle(.white)
            
            if let goal, goal > 0 {
                Text(AppLocalization.key("EFSA total-water reference: \(Int(goal)) ml/day"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))

                Text(progress >= 1.0
                     ? AppLocalization.key("Logged drinks reached the reference; food water is not counted.")
                     : AppLocalization.key("Progress compares logged drinks with a total-water reference."))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.glindaPink)
            } else {
                Text(AppLocalization.key("No general water reference is available for this profile. You can still log beverages."))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ProgressMilestonesCard: View {
    let progress: Double
    let tint: Color
    private let milestones: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.key("Beverage volume vs total-water reference"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            HStack(spacing: 8) {
                ForEach(milestones, id: \.self) { milestone in
                    let reached = progress >= milestone
                    VStack(spacing: 5) {
                        Circle()
                            .fill(reached ? tint : Color.white.opacity(0.16))
                            .frame(width: 12, height: 12)
                        
                        Text("\(Int(milestone * 100))%")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(reached ? .white : .white.opacity(0.54))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            GeometryReader { geometry in
                let clamped = min(max(progress, 0.0), 1.25) / 1.25
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.85), tint.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * clamped)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct DrinkPickerCard: View {
    let availableDrinkTypes: [HydrationDrinkType]
    @Binding var selectedType: HydrationDrinkType
    @Binding var selectedMilkChoice: MilkChoice
    @Binding var selectedAmount: Double
    let waterColor: Color
    
    let onAdd: (HydrationDrinkSelection, Double) -> Void
    let onReset: () -> Void
    
    private var currentSelection: HydrationDrinkSelection {
        HydrationDrinkCatalog.selection(
            for: selectedType,
            milkChoice: selectedType.supportsMilkChoice ? selectedMilkChoice : nil
        )
    }
    
    private var currentTintColor: Color {
        color(for: currentSelection)
    }
    
    private func color(for selection: HydrationDrinkSelection) -> Color {
        selection.type == .water ? waterColor : selection.liquidColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalization.key( "Add drink"))
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(availableDrinkTypes) { drink in
                    let isSelected = selectedType == drink
                    let selection = HydrationDrinkCatalog.selection(
                        for: drink,
                        milkChoice: drink.supportsMilkChoice ? selectedMilkChoice : nil
                    )
                    
                    Button {
                        selectedType = drink
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selection.iconName)
                            Text(drink.displayName)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.84) : Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? color(for: selection) : Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            
            if selectedType.supportsMilkChoice {
                Picker(AppLocalization.key( "Milk"), selection: $selectedMilkChoice) {
                    ForEach(MilkChoice.allCases) { milk in
                        Text(milk.displayName).tag(milk)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Text(AppLocalization.key( "Volume (ml)"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.86))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currentSelection.volumeOptions, id: \.self) { amount in
                        let isSelected = selectedAmount == amount
                        Button {
                            selectedAmount = amount
                        } label: {
                            Text("\(Int(amount)) ml")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.black.opacity(0.84) : .white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(isSelected ? currentTintColor : Color.white.opacity(0.09))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                Label(AppLocalization.key("\(Int(selectedAmount)) ml beverage volume"), systemImage: "drop.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                Text(AppLocalization.key("Recorded as beverage volume"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            
            HStack(spacing: 12) {
                Button {
                    onAdd(currentSelection, selectedAmount)
                } label: {
                    Label(AppLocalization.key( "Add drink"), systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(currentTintColor)
                
                Button {
                    onReset()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .padding(10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.75))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onChange(of: selectedType) { _, newType in
            if let firstAmount = newType.volumeOptions.first {
                selectedAmount = firstAmount
            }
        }
    }
}

private struct LastDrinkBadge: View {
    let entry: WaterEntry
    let waterColor: Color
    
    private var selection: HydrationDrinkSelection {
        HydrationDrinkCatalog.selection(for: entry)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: selection.iconName)
                .foregroundStyle(selection.type == .water ? waterColor : selection.liquidColor)
            
            HStack(spacing: 0) {
                Text("Last: ")
                selection.localizedName
                Text(AppLocalization.key(" • \(Int(entry.amountMl)) ml logged"))
            }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
            
            Spacer()
            
            Text(entry.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.54))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HydrationSourcesCard: View {
    private let references = HydrationDrinkCatalog.references
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.key("About the water reference"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(AppLocalization.key("EFSA adequate intakes are total water from all beverages and food moisture. This tracker counts only drinks you log."))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))

            Text(AppLocalization.key("The reference assumes moderate temperature and activity. It is not adjusted for heat, intense exercise, pregnancy, breastfeeding, or medical fluid restrictions."))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))

            Text(AppLocalization.key("Every drink is counted by its logged volume. Evidence does not support the precise per-drink hydration percentages previously shown."))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
            
            ForEach(references.prefix(3)) { reference in
                Link(destination: reference.url) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reference.title)
                            Text(reference.detail)
                        }
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WaterTrackerView: View {
    @Environment(ProfileManager.self) private var profileManager
    @Environment(WaterManager.self) private var waterManager
    
    @AppStorage("selectedWickedCharacter") private var selectedCharacterRaw: String = WickedCharacter.glinda.rawValue
    @AppStorage("hydrationDefaultDrinkTypeRaw") private var hydrationDefaultDrinkTypeRaw: String = HydrationDrinkType.water.rawValue
    @AppStorage("hydrationDefaultVolumeMl") private var hydrationDefaultVolumeMl: Double = 250
    @AppStorage("hydrationPreferredMilkRaw") private var hydrationPreferredMilkRaw: String = MilkChoice.regular.rawValue
    @AppStorage("hydrationFavoriteDrinkIDs") private var hydrationFavoriteDrinkIDsRaw: String = "water"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("reduceMotionEnabled") private var reduceMotionEnabled: Bool = false
    
    @State private var selectedDrinkType: HydrationDrinkType = .water
    @State private var selectedMilkChoice: MilkChoice = .regular
    @State private var selectedAmount: Double = 250
    @State private var showingLogError = false
    @State private var logErrorMessage: LocalizedStringKey?
    
    private var selectedCharacter: WickedCharacter {
        get { WickedCharacter(rawValue: selectedCharacterRaw) ?? .glinda }
        set { selectedCharacterRaw = newValue.rawValue }
    }
    
    private var selectedDrink: HydrationDrinkSelection {
        HydrationDrinkCatalog.selection(
            for: selectedDrinkType,
            milkChoice: selectedDrinkType.supportsMilkChoice ? selectedMilkChoice : nil
        )
    }
    
    private var preferredDrinkType: HydrationDrinkType {
        HydrationDrinkType(rawValue: hydrationDefaultDrinkTypeRaw) ?? .water
    }
    
    private var preferredMilkChoice: MilkChoice {
        MilkChoice(rawValue: hydrationPreferredMilkRaw) ?? .regular
    }
    
    private var availableDrinkTypes: [HydrationDrinkType] {
        let ids = hydrationFavoriteDrinkIDsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let selectedTypes = Set(
            ids.compactMap { id -> HydrationDrinkType? in
                let rawType = id.split(separator: ":").first.map(String.init) ?? id
                return HydrationDrinkType(rawValue: rawType)
            }
        )
        
        let orderedFavorites = HydrationDrinkType.allCases.filter { selectedTypes.contains($0) }
        return orderedFavorites.isEmpty ? HydrationDrinkType.allCases : orderedFavorites
    }
    
    private var activeLiquidColor: Color {
        if let lastEntry = waterManager.todayEntries.first {
            let selection = HydrationDrinkCatalog.selection(for: lastEntry)
            return selection.type == .water ? selectedCharacter.waterColor : selection.liquidColor
        }
        return selectedDrink.type == .water ? selectedCharacter.waterColor : selectedDrink.liquidColor
    }
    
    private var displayGoal: WaterGoal {
        if let goal = waterManager.goal {
            return goal
        }
        
        let currentVolume = waterManager.todayRecord?.totalVolumeML ?? 0.0
        return WaterGoal(
            dailyGoalMl: profileManager.userProfile?.calculateWaterGoalMl(),
            currentBeverageVolumeMl: currentVolume
        )
    }
    
    private func applyHydrationDefaults() {
        selectedMilkChoice = preferredMilkChoice
        
        let initialDrinkType: HydrationDrinkType
        if availableDrinkTypes.contains(preferredDrinkType) {
            initialDrinkType = preferredDrinkType
        } else {
            initialDrinkType = availableDrinkTypes.first ?? .water
        }
        selectedDrinkType = initialDrinkType
        
        let selection = HydrationDrinkCatalog.selection(
            for: initialDrinkType,
            milkChoice: initialDrinkType.supportsMilkChoice ? selectedMilkChoice : nil
        )
        
        if selection.volumeOptions.contains(hydrationDefaultVolumeMl) {
            selectedAmount = hydrationDefaultVolumeMl
        } else {
            selectedAmount = selection.volumeOptions.first ?? 250
        }
    }
    
    private func triggerAddHaptic() {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    private func triggerResetHaptic() {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
    
    var body: some View {
        navigationScreen
            .onAppear(perform: applyHydrationDefaults)
            .onChange(of: hydrationFavoriteDrinkIDsRaw) { _, _ in
                guard availableDrinkTypes.contains(selectedDrinkType) else {
                    selectedDrinkType = availableDrinkTypes.first ?? .water
                    selectedAmount = selectedDrinkType.volumeOptions.first ?? 250
                    return
                }
            }
            .onChange(of: hydrationPreferredMilkRaw) { _, _ in
                selectedMilkChoice = preferredMilkChoice
            }
            .onChange(of: hydrationDefaultDrinkTypeRaw) { _, _ in
                applyHydrationDefaults()
            }
            .onChange(of: hydrationDefaultVolumeMl) { _, newValue in
                if selectedDrink.volumeOptions.contains(newValue) {
                    selectedAmount = newValue
                }
            }
            .alert(AppLocalization.key("Operation Error"), isPresented: $showingLogError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(logErrorMessage ?? AppLocalization.key("The operation could not be completed. Please try again later."))
            }
    }

    private var navigationScreen: some View {
        NavigationStack {
            trackerContent
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.darkBackground.opacity(0.55), for: .navigationBar)
                .navigationTitle("Hydration Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { trackerToolbar }
        }
    }

    private var trackerContent: some View {
        ZStack {
            WickedBackgroundView()
            ScrollView(showsIndicators: false) {
                trackerSections
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
    }

    private var trackerSections: some View {
        let goal = displayGoal
        let rawProgress = goal.dailyGoalMl.map { goal.currentBeverageVolumeMl / $0 } ?? 0
        let characterProgress = min(max(rawProgress, 0.0), 1.0)
        let milestoneProgress = min(max(rawProgress, 0.0), 1.25)

        return VStack(spacing: 14) {
            WickedCharacterTracker(
                character: selectedCharacter,
                progress: characterProgress,
                liquidColor: activeLiquidColor,
                reduceMotion: reduceMotionEnabled
            )
            .frame(height: 340)
            .padding(.horizontal, 36)
            .padding(.top, 6)

            GoalGlassCard(
                currentBeverageVolume: goal.currentBeverageVolumeMl,
                goal: goal.dailyGoalMl,
                progress: rawProgress
            )

            if goal.dailyGoalMl != nil {
                ProgressMilestonesCard(progress: milestoneProgress, tint: activeLiquidColor)
            }

            drinkPicker

            if let lastLog = waterManager.todayEntries.first {
                LastDrinkBadge(entry: lastLog, waterColor: selectedCharacter.waterColor)
            }

            HydrationSourcesCard()
        }
    }

    private var drinkPicker: some View {
        DrinkPickerCard(
            availableDrinkTypes: availableDrinkTypes,
            selectedType: $selectedDrinkType,
            selectedMilkChoice: $selectedMilkChoice,
            selectedAmount: $selectedAmount,
            waterColor: selectedCharacter.waterColor,
            onAdd: addDrink,
            onReset: resetToday
        )
    }

    @ToolbarContentBuilder
    private var trackerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Select Character", selection: $selectedCharacterRaw) {
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

    private func addDrink(_ selection: HydrationDrinkSelection, amount: Double) {
        triggerAddHaptic()
        Task {
            do {
                try await waterManager.addLog(amountMl: amount, beverage: selection)
            } catch {
                logErrorMessage = AppLocalization.key("An unknown error occurred.")
                showingLogError = true
            }
        }
    }

    private func resetToday() {
        triggerResetHaptic()
        waterManager.resetTodayIntake()
    }
}
