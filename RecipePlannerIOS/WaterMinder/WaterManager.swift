import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
class WaterManager {
    private struct PendingEntry {
        let documentID: String
        let entry: WaterEntry
    }

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private let userId: String
    private let calendar: Calendar
    private let now: () -> Date
    private var recordsRevision = 0
    private var hasClearedLocalData = false
    private var pendingEntries: [UUID: PendingEntry] = [:]

    private(set) var currentDate: Date
    var allRecords: [WaterRecord] = []

    /// A date-filtered view of the authoritative entry collection. Records that were
    /// historically written into another day's document still appear on their timestamp's day.
    var todayRecord: WaterRecord? {
        guard !hasClearedLocalData else { return nil }
        return WaterRecord(
            id: WaterIntakeDay.documentID(for: currentDate, calendar: calendar),
            userId: userId,
            entries: WaterIntakeDay.entries(in: allRecords, on: currentDate, calendar: calendar),
            amountMl: 0,
            timestamp: currentDate
        )
    }

    var todayEntries: [WaterEntry] {
        WaterIntakeDay.entries(in: allRecords, on: currentDate, calendar: calendar)
            .sorted { $0.timestamp > $1.timestamp }
    }

    var todayTotalVolumeMl: Double {
        todayEntries.reduce(0) { $0 + $1.amountMl }
    }

    init(
        userId: String,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = { Date() }
    ) {
        self.userId = userId
        self.calendar = calendar
        self.now = now
        self.currentDate = now()
        startListeningForRecords()
    }

    deinit {
        listenerRegistration?.remove()
    }

    /// Refreshes the local calendar day when the app resumes or the day/time zone changes.
    func refreshCurrentDate(at date: Date? = nil) {
        currentDate = date ?? now()
    }

    // MARK: - Firestore observation

    private func startListeningForRecords() {
        listenerRegistration?.remove()

        let collectionRef = db.collection("users").document(userId)
            .collection("waterRecords")

        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("Listening error on WaterRecords: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("WaterRecords snapshot is unavailable")
                return
            }

            let records = documents.compactMap { try? $0.data(as: WaterRecord.self) }
                .sorted { ($0.id ?? "") > ($1.id ?? "") }

            DispatchQueue.main.async {
                guard self.listenerRegistration != nil else { return }
                self.recordsRevision += 1
                self.allRecords = self.applyingPendingEntries(to: records)
            }
        }
    }

    /// Performs an explicit refresh for the Settings screen. Live snapshots remain the
    /// primary source of truth; an older one-shot read cannot replace a newer listener event.
    func loadHistoricalRecords() async {
        let revisionAtStart = await MainActor.run { recordsRevision }
        let collectionRef = db.collection("users").document(userId)
            .collection("waterRecords")

        do {
            let snapshot = try await collectionRef.getDocuments()
            let records = snapshot.documents.compactMap { try? $0.data(as: WaterRecord.self) }
                .sorted { ($0.id ?? "") > ($1.id ?? "") }

            await MainActor.run {
                guard recordsRevision == revisionAtStart else { return }
                recordsRevision += 1
                allRecords = applyingPendingEntries(to: records)
            }
        } catch {
            print("Error loading historical water records: \(error.localizedDescription)")
        }
    }

    // MARK: - Firestore actions

    func addLog(amountMl: Double, beverage: HydrationDrinkSelection) async throws {
        guard amountMl.isFinite, amountMl > 0 else {
            throw NSError(
                domain: "WaterManagerError",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Drink amount must be greater than zero."]
            )
        }

        let timestamp = now()
        let dateKey = WaterIntakeDay.documentID(for: timestamp, calendar: calendar)
        let newEntry = WaterEntry(
            amountMl: amountMl,
            timestamp: timestamp,
            beverageId: beverage.id,
            beverageName: beverage.englishName,
            hydrationFactor: 1.0
        )
        let encodedEntry = try Firestore.Encoder().encode(newEntry)
        let documentRef = db.collection("users").document(userId)
            .collection("waterRecords")
            .document(dateKey)

        // arrayUnion is an atomic append, works with Firestore's offline queue, and avoids
        // overwriting another entry when multiple writes use the same day's document.
        let update: [String: Any] = [
            "userId": userId,
            "entries": FieldValue.arrayUnion([encodedEntry]),
            "amountMl": 0.0,
            "timestamp": Timestamp(date: timestamp)
        ]

        await MainActor.run {
            refreshCurrentDate(at: timestamp)
            pendingEntries[newEntry.id] = PendingEntry(documentID: dateKey, entry: newEntry)
            appendLocally(newEntry, documentID: dateKey)
        }

        documentRef.setData(update, merge: true) { [weak self] error in
            guard let error else { return }
            print("Error saving water entry: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self?.removePendingEntry(id: newEntry.id)
            }
        }
    }

    func addLog(amountMl: Double) async throws {
        let water = HydrationDrinkSelection(type: .water, milkChoice: nil)
        try await addLog(amountMl: amountMl, beverage: water)
    }

    /// Clears entries for the current local calendar day from every daily document. This
    /// also handles legacy entries that crossed midnight into the previous day's document.
    func resetTodayIntake() {
        let resetDate = now()
        refreshCurrentDate(at: resetDate)

        Task {
            do {
                try await removeEntries(on: resetDate)
            } catch {
                print("Error resetting water intake: \(error.localizedDescription)")
            }
        }
    }

    private func removeEntries(on date: Date) async throws {
        let collectionRef = db.collection("users").document(userId)
            .collection("waterRecords")
        let snapshot = try await collectionRef.getDocuments()
        let todayKey = WaterIntakeDay.documentID(for: date, calendar: calendar)
        var foundTodayDocument = false

        for document in snapshot.documents {
            if document.documentID == todayKey {
                foundTodayDocument = true
            }

            guard let record = try? document.data(as: WaterRecord.self) else { continue }
            let entriesToRemove = WaterIntakeDay.entries(in: [record], on: date, calendar: calendar)
            guard !entriesToRemove.isEmpty else { continue }

            let encodedEntries = try entriesToRemove.map { try Firestore.Encoder().encode($0) }
            document.reference.updateData([
                "entries": FieldValue.arrayRemove(encodedEntries)
            ]) { error in
                if let error {
                    print("Error clearing daily water entries: \(error.localizedDescription)")
                }
            }
        }

        if !foundTodayDocument {
            var emptyRecord = WaterRecord.empty(userId: userId)
            emptyRecord.id = todayKey
            try collectionRef.document(todayKey).setData(from: emptyRecord)
        }

        await MainActor.run {
            pendingEntries = pendingEntries.filter {
                !WaterIntakeDay.contains($0.value.entry.timestamp, on: date, calendar: calendar)
            }
            for index in allRecords.indices {
                allRecords[index].entries.removeAll {
                    WaterIntakeDay.contains($0.timestamp, on: date, calendar: calendar)
                }
            }
            if !allRecords.contains(where: { $0.id == todayKey }) {
                var emptyRecord = WaterRecord.empty(userId: userId)
                emptyRecord.id = todayKey
                allRecords.append(emptyRecord)
                allRecords.sort { ($0.id ?? "") > ($1.id ?? "") }
            }
        }
    }

    // MARK: - Local state

    private func appendLocally(_ entry: WaterEntry, documentID: String) {
        let alreadyPresent = WaterIntakeDay.entries(in: allRecords).contains { $0.id == entry.id }
        allRecords = WaterIntakeDay.appending(entry, documentID: documentID, to: allRecords, userId: userId)
        if !alreadyPresent { recordsRevision += 1 }
    }

    private func applyingPendingEntries(to fetchedRecords: [WaterRecord]) -> [WaterRecord] {
        var records = fetchedRecords
        var fetchedEntryIDs = Set(records.flatMap(\.entries).map(\.id))
        var confirmedPendingIDs: [UUID] = []

        for (id, pending) in pendingEntries {
            if fetchedEntryIDs.contains(id) {
                confirmedPendingIDs.append(id)
                continue
            }

            records = WaterIntakeDay.appending(
                pending.entry,
                documentID: pending.documentID,
                to: records,
                userId: userId
            )
            fetchedEntryIDs.insert(id)
        }

        confirmedPendingIDs.forEach { pendingEntries.removeValue(forKey: $0) }
        return records.sorted { ($0.id ?? "") > ($1.id ?? "") }
    }

    private func removePendingEntry(id: UUID) {
        guard let pending = pendingEntries.removeValue(forKey: id) else { return }
        if let index = allRecords.firstIndex(where: { $0.id == pending.documentID }) {
            allRecords[index].entries.removeAll { $0.id == id }
        }
        recordsRevision += 1
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
            allRecords = []
            hasClearedLocalData = false
        }
    }

    func clearLocalData() {
        stopListening()
        allRecords = []
        hasClearedLocalData = true
    }
}
