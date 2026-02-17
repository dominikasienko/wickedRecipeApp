import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
class WaterManager {
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    var goal: WaterGoal?
    var todayRecord: WaterRecord?
    var allRecords: [WaterRecord] = []
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        self.todayRecord = WaterRecord.empty(userId: userId)
        
        startListeningForTodayRecord()
        
        Task {
            await loadHistoricalRecords()
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }

    /// Oblicza i ustawia cel dzienny, a następnie aktualizuje bieżące spożycie na podstawie aktualnego rekordu.
    func calculateGoal(weightKg: Double, activityLevel: String) {
        var calculatedGoal = weightKg * 30
        
        if activityLevel.contains("High activity") || activityLevel.contains("Very high activity") {
            calculatedGoal *= 1.2
        } else if activityLevel.contains("Low activity") {
            calculatedGoal *= 0.9
        }
        
        let finalGoal = (calculatedGoal / 50.0).rounded() * 50.0
        let currentIntake = todayRecord?.totalIntakeML ?? 0.0
        
        self.goal = WaterGoal(
            dailyGoalMl: finalGoal,
            currentIntakeMl: currentIntake
        )
    }
    
// MARK: --- LOGIKA FIRESTORE ---
    
    private func startListeningForTodayRecord() {
        listenerRegistration?.remove()

        let todayKey = WaterRecord.formattedDate(Date())
        let docRef = db.collection("users").document(userId)
            .collection("waterRecords")
            .document(todayKey)
        
        listenerRegistration = docRef.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Listening error on WaterRecord: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("Snapshot is nil")
                return
            }

            if snapshot.exists, let record = try? snapshot.data(as: WaterRecord.self) {
                
                DispatchQueue.main.async {
                    self.todayRecord = record
                    if self.goal != nil {
                        self.goal?.currentIntakeMl = record.totalIntakeML
                    }
                    self.updateOrAddRecord(record)
                }
            } else {
                DispatchQueue.main.async {
                    let emptyRecord = WaterRecord.empty(userId: self.userId)
                    self.todayRecord = emptyRecord
                    
                    if self.goal != nil {
                        self.goal?.currentIntakeMl = 0.0
                    }
                    
                    guard let emptyRecordID = emptyRecord.id else {
                        print("Warning: Empty record was created without an ID. Cannot remove from allRecords.")
                        return
                    }
                    self.removeRecord(id: emptyRecordID)
                }
            }
        }
    }
    
// MARK: --- POBIERANIE HISTORYCZNE ---

    /// Pobiera wszystkie WaterRecords dla użytkownika. Wywoływane raz przy starcie.
    func loadHistoricalRecords() async {
        let collectionRef = db.collection("users").document(userId)
            .collection("waterRecords")
        
        do {
            let snapshot = try await collectionRef.getDocuments()
            
            let records = snapshot.documents.compactMap { document -> WaterRecord? in
                try? document.data(as: WaterRecord.self)
            }
            let sortedRecords = records.sorted { (r1, r2) -> Bool in
                return (r1.id ?? "") > (r2.id ?? "")
            }
            
            DispatchQueue.main.async {
                self.allRecords = sortedRecords
            }
            
        } catch {
            print("Error loading historical water records: \(error.localizedDescription)")
        }
    }

// MARK: --- LOGIKA FIRESTORE: AKCJE ---
    func addLog(amountMl: Double) async throws {
        guard let currentRecord = self.todayRecord else {
            print("No record to log for today.")
            throw NSError(domain: "WaterManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error: No WaterRecord loaded."])
        }

        let newEntry = WaterEntry(amountMl: amountMl)
        var updatedRecord = currentRecord
        updatedRecord.entries.append(newEntry)
        
        let todayKey = updatedRecord.id ?? WaterRecord.formattedDate(Date())
        let docRef = db.collection("users").document(userId)
            .collection("waterRecords")
            .document(todayKey)
        
        try docRef.setData(from: updatedRecord)
    }
    
    func resetTodayIntake() {
        Task {
            do {
                let todayKey = WaterRecord.formattedDate(Date())
                let emptyRecord = WaterRecord.empty(userId: self.userId)
                
                let docRef = db.collection("users").document(userId)
                    .collection("waterRecords")
                    .document(todayKey)
                
                // Użycie setData z nowym, pustym rekordem.
                try docRef.setData(from: emptyRecord)
                print("Successfully reset today's water intake.")
                
            } catch {
                print("Error resetting water intake: \(error.localizedDescription)")
            }
        }
    }
    
// MARK: --- POMOCNICZE WŁAŚCIWOŚCI I METODY DLA WIDOKÓW ---
    var todayEntries: [WaterEntry] {
        return todayRecord?.entries.sorted(by: { $0.timestamp > $1.timestamp }) ?? []
    }
    
    /// Aktualizuje lub dodaje rekord do tablicy allRecords.
    private func updateOrAddRecord(_ record: WaterRecord) {
        if let index = allRecords.firstIndex(where: { (item: WaterRecord) in item.id == record.id }) {
            allRecords[index] = record
        } else {
            allRecords.append(record)
            
            allRecords.sort { (a, b) in
                return (a.id ?? "") > (b.id ?? "")
            }
        }
    }
    
    /// Usuwa rekord z tablicy allRecords.
    private func removeRecord(id: String) {
        allRecords.removeAll(where: { (item: WaterRecord) in item.id == id })
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }
    
    func deleteAllWaterRecords() async throws {
            let collectionRef = db.collection("users").document(userId)
                .collection("waterRecords")
            
            let snapshot = try await collectionRef.getDocuments()
            guard !snapshot.documents.isEmpty else {
                print("No water records found to delete.")
                return
            }
            
            let batch = db.batch()
            snapshot.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            
            DispatchQueue.main.async {
                self.allRecords = []
                self.todayRecord = WaterRecord.empty(userId: self.userId)
                if self.goal != nil {
                    self.goal?.currentIntakeMl = 0
                }
                print("Successfully deleted all water history.")
            }
    }
}
