//
//  WaterEntry.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 17/11/2025.
//

import Foundation
import FirebaseFirestore

/// Model dla pojedynczego wpisu spożycia wody.
/// Jest używany jako element tablicy w dokumencie WaterRecord.
struct WaterEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    
    var amountMl: Double
    var timestamp: Date
    
    init(amountMl: Double, timestamp: Date = Date()) {
        self.amountMl = amountMl
        self.timestamp = timestamp
    }
}

struct WaterRecord: Codable, Identifiable {
    @DocumentID var id: String?
    
    let userId: String
    var entries: [WaterEntry]
    let amountMl: Double
    let timestamp: Date

    var totalIntakeML: Double {
        return entries.reduce(0) { $0 + $1.amountMl }
    }
    
    static func empty(userId: String) -> WaterRecord {
        return WaterRecord(
            id: nil,
            userId: userId,
            entries: [],
            amountMl: 0.0,
            timestamp: Date.now
        )
    }

    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct WaterGoal {
    var dailyGoalMl: Double
    var currentIntakeMl: Double = 0.0
}
