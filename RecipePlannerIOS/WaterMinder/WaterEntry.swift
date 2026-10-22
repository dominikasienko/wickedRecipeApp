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
    var id: UUID
    
    var amountMl: Double
    var timestamp: Date
    var beverageId: String
    var beverageName: String
    /// Kept to decode existing Firestore records; intake calculations no longer apply this unsupported factor.
    var hydrationFactor: Double
    
    init(
        id: UUID = UUID(),
        amountMl: Double,
        timestamp: Date = Date(),
        beverageId: String = "water",
        beverageName: String = "Water",
        hydrationFactor: Double = 1.0
    ) {
        self.id = id
        self.amountMl = amountMl
        self.timestamp = timestamp
        self.beverageId = beverageId
        self.beverageName = beverageName
        self.hydrationFactor = hydrationFactor
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case amountMl
        case timestamp
        case beverageId
        case beverageName
        case hydrationFactor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        amountMl = try container.decodeIfPresent(Double.self, forKey: .amountMl) ?? 0.0
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        beverageId = try container.decodeIfPresent(String.self, forKey: .beverageId) ?? "water"
        beverageName = try container.decodeIfPresent(String.self, forKey: .beverageName) ?? "Water"
        hydrationFactor = try container.decodeIfPresent(Double.self, forKey: .hydrationFactor) ?? 1.0
    }
}

struct WaterRecord: Codable, Identifiable {
    @DocumentID var id: String?
    
    let userId: String
    var entries: [WaterEntry]
    let amountMl: Double
    let timestamp: Date

    var totalVolumeML: Double {
        return entries.reduce(0) { $0 + $1.amountMl }
    }
    
    var totalIntakeML: Double {
        totalVolumeML
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
    var dailyGoalMl: Double?
    var currentBeverageVolumeMl: Double = 0.0
}
