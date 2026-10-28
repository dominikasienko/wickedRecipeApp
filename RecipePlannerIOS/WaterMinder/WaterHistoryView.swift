//
//  WaterHistoryView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct WaterHistoryView: View {
    @Environment(WaterManager.self) private var waterManager
    @AppStorage("selectedWickedCharacter") private var selectedCharacterRaw: String = WickedCharacter.glinda.rawValue

    private var selectedCharacter: WickedCharacter {
        WickedCharacter(rawValue: selectedCharacterRaw) ?? .glinda
    }

    private var allEntries: [WaterEntry] {
        WaterIntakeDay.entries(in: waterManager.allRecords)
    }

    private var totalHistoricalBeverageVolume: Double {
        let calendar = Calendar.current
        let currentDate = waterManager.currentDate
        let historicalLogs = allEntries.filter { entry in
            !calendar.isDate(entry.timestamp, inSameDayAs: currentDate)
        }
        return historicalLogs.reduce(0) { $0 + $1.amountMl }
    }
    
    private var groupedEntries: [Date: [WaterEntry]] {
        Dictionary(grouping: allEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
    }
    
    private var sortedDates: [Date] {
        groupedEntries.keys.sorted(by: >)
    }

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            WickedAmbientGlowLayer(pinkOpacity: 0.4, greenOpacity: 0)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    if totalHistoricalBeverageVolume > 0 {
                        HistoricalSummaryCard(
                            totalVolume: totalHistoricalBeverageVolume
                        )
                            .padding([.horizontal, .top])
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Log History")
                            .font(.title2).bold()
                            .foregroundStyle(.white)
                            .padding(.leading)
                        
                        ForEach(sortedDates, id: \.self) { date in
                            if let logs = groupedEntries[date], !logs.isEmpty {
                                Section {
                                    ForEach(logs.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                                        LogEntryRow(entry: entry, waterColor: selectedCharacter.waterColor)
                                            .listRowBackground(Color.clear)
                                    }
                                } header: {
                                    Text(date, style: .date)
                                        .font(.caption).bold()
                                        .foregroundStyle(dateTodayColor(date: date))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .wickedReadableWidth(760)
            }
        }
        .navigationTitle("Hydration History")
    }
    
    private func dateTodayColor(date: Date) -> Color {
        if Calendar.current.isDateInToday(date) {
            return .glindaPink
        } else {
            return .wickedGreen
        }
    }
}

// MARK: --- KARTA PODSUMOWANIA HISTORYCZNEGO ---
struct HistoricalSummaryCard: View {
    let totalVolume: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Historical Total")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            HStack {
                Image(systemName: "drop.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.wickedGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(totalVolume)) ml")
                        .font(.largeTitle).bold()
                        .foregroundStyle(Color.glindaPink)
                    
                    Text(AppLocalization.key("Total logged beverage volume before today."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: --- WIDOK POMOCNICZY ---
struct LogEntryRow: View {
    let entry: WaterEntry 
    let waterColor: Color
    
    private var selection: HydrationDrinkSelection {
        HydrationDrinkCatalog.selection(for: entry)
    }
    
    var body: some View {
        HStack {
            Image(systemName: selection.iconName)
                .foregroundStyle(selection.type == .water ? waterColor : selection.liquidColor)
            
            VStack(alignment: .leading, spacing: 2) {
                selection.localizedName
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(AppLocalization.key("\(Int(entry.amountMl)) ml logged"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(entry.timestamp, style: .time)
                .foregroundStyle(.gray)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
}
