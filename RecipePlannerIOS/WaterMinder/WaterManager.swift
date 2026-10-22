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

    /// Sets the EFSA total-water reference when the profile can use general estimates.
    func calculateGoal(profile: UserProfile) {
        let reference = profile.calculateWaterGoalMl()
        let currentVolume = todayRecord?.totalVolumeML ?? 0.0
        
        self.goal = WaterGoal(
            dailyGoalMl: reference,
            currentBeverageVolumeMl: currentVolume
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
                        self.goal?.currentBeverageVolumeMl = record.totalVolumeML
                    }
                    self.updateOrAddRecord(record)
                }
            } else {
                DispatchQueue.main.async {
                    let emptyRecord = WaterRecord.empty(userId: self.userId)
                    self.todayRecord = emptyRecord
                    
                    if self.goal != nil {
                        self.goal?.currentBeverageVolumeMl = 0.0
                    }
                    
                    self.removeRecord(id: todayKey)
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
    func addLog(amountMl: Double, beverage: HydrationDrinkSelection) async throws {
        guard let currentRecord = self.todayRecord else {
            print("No record to log for today.")
            throw NSError(domain: "WaterManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error: No WaterRecord loaded."])
        }
        
        guard amountMl > 0 else {
            throw NSError(domain: "WaterManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Drink amount must be greater than zero."])
        }

        let newEntry = WaterEntry(
            amountMl: amountMl,
            beverageId: beverage.id,
            beverageName: beverage.englishName,
            hydrationFactor: 1.0
        )
        var updatedRecord = currentRecord
        updatedRecord.entries.append(newEntry)
        
        let todayKey = updatedRecord.id ?? WaterRecord.formattedDate(Date())
        updatedRecord.id = todayKey
        let docRef = db.collection("users").document(userId)
            .collection("waterRecords")
            .document(todayKey)
        
        try docRef.setData(from: updatedRecord)
        
        await MainActor.run {
            self.todayRecord = updatedRecord
            self.updateOrAddRecord(updatedRecord)
            self.refreshGoalTotals(with: updatedRecord)
        }
    }
    
    func addLog(amountMl: Double) async throws {
        let water = HydrationDrinkSelection(type: .water, milkChoice: nil)
        try await addLog(amountMl: amountMl, beverage: water)
    }
    
    func resetTodayIntake() {
        Task {
            do {
                let todayKey = WaterRecord.formattedDate(Date())
                var emptyRecord = WaterRecord.empty(userId: self.userId)
                emptyRecord.id = todayKey
                
                let docRef = db.collection("users").document(userId)
                    .collection("waterRecords")
                    .document(todayKey)
                
                // Użycie setData z nowym, pustym rekordem.
                try docRef.setData(from: emptyRecord)
                await MainActor.run {
                    self.todayRecord = emptyRecord
                    self.removeRecord(id: todayKey)
                    self.refreshGoalTotals(with: emptyRecord)
                }
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
        guard Auth.auth().currentUser?.uid == userId else {
            throw NSError(domain: "WaterManagerError", code: 403)
        }

        let collectionRef = db.collection("users").document(userId)
            .collection("waterRecords")
        let snapshot = try await collectionRef.getDocuments()

        for start in stride(from: 0, to: snapshot.documents.count, by: 450) {
            let batch = db.batch()
            for document in snapshot.documents[start..<min(start + 450, snapshot.documents.count)] {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }

        await MainActor.run {
            self.allRecords = []
            self.todayRecord = WaterRecord.empty(userId: self.userId)
            self.goal?.currentBeverageVolumeMl = 0
        }
    }

    func clearLocalData() {
        stopListening()
        allRecords = []
        todayRecord = nil
        goal = nil
    }
    
    private func refreshGoalTotals(with record: WaterRecord) {
        guard goal != nil else { return }
        goal?.currentBeverageVolumeMl = record.totalVolumeML
    }
}
