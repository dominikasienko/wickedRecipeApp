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

    /// Snapshot of the tracker estimate that applied on this record's local calendar day.
    /// Older documents decode with nil and are deliberately excluded from historical goal rates.
    var dailyTargetDate: Date? = nil
    var dailyTargetMl: Double? = nil
    var dailyTargetMethod: String? = nil
    var dailyTargetRecordedAt: Date? = nil
    var dailyTargetUnavailableReason: String? = nil

    var totalVolumeML: Double {
        WaterIntakeDay.entries(in: [self]).reduce(0) { $0 + $1.amountMl }
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
        formattedDate(date, calendar: .autoupdatingCurrent)
    }

    static func formattedDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Date and aggregation rules shared by the tracker, history, and tests.
enum WaterIntakeDay {
    static func documentID(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        WaterRecord.formattedDate(date, calendar: calendar)
    }

    static func interval(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval? {
        calendar.dateInterval(of: .day, for: date)
    }

    static func contains(_ timestamp: Date, on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let interval = interval(containing: date, calendar: calendar) else { return false }
        return timestamp >= interval.start && timestamp < interval.end
    }

    static func entries(in records: [WaterRecord]) -> [WaterEntry] {
        var seenIDs = Set<UUID>()
        return records
            .flatMap(\.entries)
            .filter {
                $0.amountMl.isFinite
                    && $0.amountMl > 0
                    && $0.timestamp.timeIntervalSince1970.isFinite
                    && seenIDs.insert($0.id).inserted
            }
    }

    static func appending(
        _ entry: WaterEntry,
        documentID: String,
        to records: [WaterRecord],
        userId: String
    ) -> [WaterRecord] {
        var updatedRecords = records
        guard !entries(in: updatedRecords).contains(where: { $0.id == entry.id }) else {
            return updatedRecords
        }

        if let index = updatedRecords.firstIndex(where: { $0.id == documentID }) {
            updatedRecords[index].entries.append(entry)
        } else {
            var record = WaterRecord(
                id: nil,
                userId: userId,
                entries: [entry],
                amountMl: 0,
                timestamp: entry.timestamp
            )
            record.id = documentID
            updatedRecords.append(record)
        }

        return updatedRecords.sorted { ($0.id ?? "") > ($1.id ?? "") }
    }

    static func replacing(
        _ entry: WaterEntry,
        in records: [WaterRecord],
        userId: String,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [WaterRecord] {
        var updatedRecords = records
        for index in updatedRecords.indices {
            updatedRecords[index].entries.removeAll { $0.id == entry.id }
        }
        return appending(
            entry,
            documentID: documentID(for: entry.timestamp, calendar: calendar),
            to: updatedRecords,
            userId: userId
        )
    }

    static func removing(entryID: UUID, from records: [WaterRecord]) -> [WaterRecord] {
        records.map { record in
            var updated = record
            updated.entries.removeAll { $0.id == entryID }
            return updated
        }
    }

    static func entries(
        in records: [WaterRecord],
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [WaterEntry] {
        entries(in: records).filter { contains($0.timestamp, on: date, calendar: calendar) }
    }

    static func total(
        in records: [WaterRecord],
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Double {
        entries(in: records, on: date, calendar: calendar)
            .reduce(0) { $0 + $1.amountMl }
    }
}

struct WaterGoal {
    var assessment: HydrationAssessment?
    var currentBeverageVolumeMl: Double = 0.0
}
