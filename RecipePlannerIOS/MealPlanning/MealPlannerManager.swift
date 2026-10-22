//
//  MealPlannerManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 19/11/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
class MealPlannerManager {
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    var allMealPlanEntries: [MealPlanEntry] = []
    
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        startListeningForEntries()
    }
    
    deinit {
        stopListening()
    }
    
// MARK:  --- METODY FIRESTORE ---
    
    /// Rozpoczyna nasłuchiwanie zmian w planie posiłków dla użytkownika.
    func startListeningForEntries() {
        listenerRegistration?.remove()
        
        let collectionRef = db.collection("users").document(userId)
            .collection("mealPlan")
        
        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Meal plan listening error: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No files in mealPlan.")
                return
            }
            
            // Mapowanie i sortowanie wpisów
            let fetchedEntries = documents.compactMap { doc -> MealPlanEntry? in
                try? doc.data(as: MealPlanEntry.self)
            }
            
            let sortedEntries = fetchedEntries.sorted { entry1, entry2 in
                if entry1.date.isSameDay(as: entry2.date) {
                    let mealOrder = AppOptionCatalog.mealTypes.map(\.id)
                    let firstIndex = mealOrder.firstIndex(of: entry1.canonicalMealType) ?? 0
                    let secondIndex = mealOrder.firstIndex(of: entry2.canonicalMealType) ?? 0
                    return firstIndex < secondIndex
                }
                return entry1.date.timeIntervalSinceReferenceDate < entry2.date.timeIntervalSinceReferenceDate
            }
            
            DispatchQueue.main.async {
                self.allMealPlanEntries = sortedEntries
            }
        }
    }
    
    /// Dodaje nowy wpis do planu posiłków.
    func addMealPlanEntry(entry: MealPlanEntry) async throws {
        let collectionRef = db.collection("users").document(userId)
            .collection("mealPlan")
        
        try collectionRef.addDocument(from: entry)
    }
    
    /// Usuwa wpis z planu posiłków na podstawie ID.
    func deleteMealPlanEntry(entryId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("mealPlan")
            .document(entryId)
            .delete()
    }
    
    /// Usuwa wszystkie wpisy planu posiłków użytkownika.
    func deleteAllMealPlanEntries() async throws {
        guard Auth.auth().currentUser?.uid == userId else {
            throw NSError(domain: "MealPlannerManagerError", code: 403)
        }

        let collectionRef = db.collection("users").document(userId)
            .collection("mealPlan")
        let snapshot = try await collectionRef.getDocuments()

        for start in stride(from: 0, to: snapshot.documents.count, by: 450) {
            let batch = db.batch()
            for document in snapshot.documents[start..<min(start + 450, snapshot.documents.count)] {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }

        await MainActor.run { self.allMealPlanEntries = [] }
    }
    
    /// Pomocnicza funkcja do filtrowania posiłków na dany dzień
    func entriesForDay(_ date: Date) -> [MealPlanEntry] {
        return allMealPlanEntries.filter { $0.date.isSameDay(as: date) }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("MealPlannerManager: Monitoring has been suspended.")
    }

    func clearLocalData() {
        stopListening()
        allMealPlanEntries = []
    }
}
