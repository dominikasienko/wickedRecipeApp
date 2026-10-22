import Foundation
import SwiftUI

struct HydrationReference: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let url: URL
}

enum MilkChoice: String, CaseIterable, Identifiable, Codable {
    case regular
    case threeTwo
    case oat
    case soy
    case almond
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .regular: return AppLocalization.key( "Regular milk")
        case .threeTwo: return AppLocalization.key( "3.2% milk")
        case .oat: return AppLocalization.key( "Oat milk")
        case .soy: return AppLocalization.key( "Soy milk")
        case .almond: return AppLocalization.key( "Almond milk")
        }
    }

    var englishName: String {
        switch self {
        case .regular: return "Regular milk"
        case .threeTwo: return "3.2% milk"
        case .oat: return "Oat milk"
        case .soy: return "Soy milk"
        case .almond: return "Almond milk"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .regular: return Color(red: 0.78, green: 0.58, blue: 0.38)
        case .threeTwo: return Color(red: 0.73, green: 0.55, blue: 0.34)
        case .oat: return Color(red: 0.78, green: 0.66, blue: 0.44)
        case .soy: return Color(red: 0.74, green: 0.72, blue: 0.60)
        case .almond: return Color(red: 0.72, green: 0.56, blue: 0.32)
        }
    }
}

enum HydrationDrinkType: String, CaseIterable, Identifiable, Codable {
    case water
    case espresso
    case doubleEspresso
    case cappuccinoSmall
    case cappuccinoLarge
    case orangeJuice
    case tea
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .water: return AppLocalization.key( "Water")
        case .espresso: return AppLocalization.key( "Espresso")
        case .doubleEspresso: return AppLocalization.key( "Double espresso")
        case .cappuccinoSmall: return AppLocalization.key( "Cappuccino (small)")
        case .cappuccinoLarge: return AppLocalization.key( "Cappuccino (large)")
        case .orangeJuice: return AppLocalization.key( "Orange juice")
        case .tea: return AppLocalization.key( "Tea")
        }
    }

    var englishName: String {
        switch self {
        case .water: return "Water"
        case .espresso: return "Espresso"
        case .doubleEspresso: return "Double espresso"
        case .cappuccinoSmall: return "Cappuccino (small)"
        case .cappuccinoLarge: return "Cappuccino (large)"
        case .orangeJuice: return "Orange juice"
        case .tea: return "Tea"
        }
    }
    
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .espresso, .doubleEspresso: return "cup.and.saucer.fill"
        case .cappuccinoSmall, .cappuccinoLarge: return "mug.fill"
        case .orangeJuice: return "sun.max.fill"
        case .tea: return "leaf.fill"
        }
    }
    
    var supportsMilkChoice: Bool {
        switch self {
        case .cappuccinoSmall, .cappuccinoLarge:
            return true
        default:
            return false
        }
    }
    
    var volumeOptions: [Double] {
        switch self {
        case .water:
            return [150, 250, 330, 500, 750]
        case .espresso:
            return [25, 30, 40]
        case .doubleEspresso:
            return [50, 60, 80]
        case .cappuccinoSmall:
            return [150, 180, 200]
        case .cappuccinoLarge:
            return [250, 300, 350]
        case .orangeJuice:
            return [150, 200, 250, 300]
        case .tea:
            return [200, 250, 300, 400]
        }
    }
    
    func liquidColor(milkChoice: MilkChoice?) -> Color {
        switch self {
        case .water:
            return Color(red: 0.20, green: 0.58, blue: 0.94)
        case .espresso:
            return Color(red: 0.44, green: 0.24, blue: 0.11)
        case .doubleEspresso:
            return Color(red: 0.36, green: 0.18, blue: 0.08)
        case .cappuccinoSmall, .cappuccinoLarge:
            let milkChoice = milkChoice ?? .regular
            return milkChoice.accentColor
        case .orangeJuice:
            return Color(red: 0.94, green: 0.49, blue: 0.10)
        case .tea:
            return Color(red: 0.67, green: 0.41, blue: 0.14)
        }
    }
    
    func beverageID(milkChoice: MilkChoice?) -> String {
        guard supportsMilkChoice, let milkChoice else {
            return rawValue
        }
        return "\(rawValue):\(milkChoice.rawValue)"
    }
    
}

struct HydrationDrinkSelection: Identifiable, Hashable {
    let type: HydrationDrinkType
    let milkChoice: MilkChoice?
    
    var id: String {
        type.beverageID(milkChoice: milkChoice)
    }
    
    @ViewBuilder
    var localizedName: some View {
        if type.supportsMilkChoice, let milkChoice {
            HStack(spacing: 0) {
                Text(type.displayName)
                Text(verbatim: " • ")
                Text(milkChoice.displayName)
            }
        } else {
            Text(type.displayName)
        }
    }

    var englishName: String {
        guard type.supportsMilkChoice, let milkChoice else { return type.englishName }
        return "\(type.englishName) • \(milkChoice.englishName)"
    }
    
    var liquidColor: Color {
        type.liquidColor(milkChoice: milkChoice)
    }
    
    var volumeOptions: [Double] {
        type.volumeOptions
    }
    
    var iconName: String {
        type.iconName
    }
}

enum HydrationDrinkCatalog {
    static let references: [HydrationReference] = [
        HydrationReference(
            id: "efsa-water-ai",
            title: AppLocalization.key("EFSA total-water adequate intake (2010)"),
            detail: AppLocalization.key("The reference includes all drinks and moisture in food; it assumes moderate temperature and activity."),
            url: URL(string: "https://efsa.onlinelibrary.wiley.com/doi/10.2903/j.efsa.2010.1459")!
        ),
        HydrationReference(
            id: "beverage-hydration-trial",
            title: AppLocalization.key("Beverage hydration index trial (2016)"),
            detail: AppLocalization.key("This short-term study does not establish precise hydration percentages for every drink."),
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/26702122/")!
        )
    ]
    
    static func selection(for type: HydrationDrinkType, milkChoice: MilkChoice?) -> HydrationDrinkSelection {
        if type.supportsMilkChoice {
            return HydrationDrinkSelection(type: type, milkChoice: milkChoice ?? .regular)
        }
        return HydrationDrinkSelection(type: type, milkChoice: nil)
    }
    
    static func selection(for entry: WaterEntry) -> HydrationDrinkSelection {
        if let selection = selectionFromID(entry.beverageId) {
            return selection
        }
        
        // Fallback for older records before beverage metadata existed.
        return HydrationDrinkSelection(type: .water, milkChoice: nil)
    }
    
    private static func selectionFromID(_ id: String) -> HydrationDrinkSelection? {
        let parts = id.split(separator: ":")
        guard let first = parts.first else { return nil }
        
        guard let type = HydrationDrinkType(rawValue: String(first)) else {
            return nil
        }
        
        let parsedMilkChoice: MilkChoice?
        if parts.count > 1 {
            parsedMilkChoice = Self.parseMilkChoice(from: String(parts[1]))
        } else {
            parsedMilkChoice = nil
        }
        
        return selection(for: type, milkChoice: parsedMilkChoice)
    }
    
    private static func parseMilkChoice(from rawValue: String) -> MilkChoice? {
        if let parsed = MilkChoice(rawValue: rawValue) {
            return parsed
        }
        
        // Backward compatibility for previously persisted IDs.
        if rawValue == "whole" {
            return .regular
        }
        
        if rawValue == "lowFat" {
            return .regular
        }
        
        return nil
    }
}
