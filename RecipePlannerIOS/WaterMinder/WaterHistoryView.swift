//
//  WaterHistoryView.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 15/11/2025.
//

import SwiftUI

struct WaterHistoryView: View {
    @Environment(WaterManager.self) private var waterManager

    private var allEntries: [WaterEntry] {
        waterManager.allRecords.flatMap { $0.entries }
    }

    private var totalHistoricalIntake: Double {
        let calendar = Calendar.current
        let historicalLogs = allEntries.filter { entry in
            !calendar.isDateInToday(entry.timestamp)
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
            
            Ellipse()
                .fill(Color.glindaPink.opacity(0.4))
                .frame(width: 300, height: 300)
                .position(x: 350, y: 50)
                .blur(radius: 100)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    if totalHistoricalIntake > 0 {
                        HistoricalSummaryCard(totalIntake: totalHistoricalIntake)
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
                                        LogEntryRow(entry: entry)
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
            }
        }
        .navigationTitle("Hydration History")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
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
    let totalIntake: Double
    
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
                    Text("\(Int(totalIntake)) ml")
                        .font(.largeTitle).bold()
                        .foregroundStyle(Color.glindaPink)
                    
                    Text("Total water logged before today.")
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
    
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.glindaPink)
            
            Text("\(Int(entry.amountMl)) ml")
                .font(.headline)
                .foregroundStyle(.white)
            
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
