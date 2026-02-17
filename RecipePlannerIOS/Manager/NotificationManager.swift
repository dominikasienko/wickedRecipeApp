//
//  NotificationManager.swift
//  RecipePlannerIOS
//
//  Created by Dominika Sieńko on 24/11/2025.
//

import SwiftUI
import Observation
import UserNotifications

@Observable
class NotificationManager {
    
    func toggleWaterReminders(isOn: Bool) {
        if isOn {
            Task {
                await requestAndScheduleReminders()
            }
        } else {
            cancelWaterReminders()
        }
    }
    
    private func requestAndScheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("Notification permission granted.")
                scheduleWaterReminders()
            } else {
                print("Notification permission denied.")
            }
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
        }
    }
    
    private func scheduleWaterReminders() {
        let center = UNUserNotificationCenter.current()
        
        center.removePendingNotificationRequests(withIdentifiers: ["waterReminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Hydrate!"
        content.body = "Don't forget to log your water intake and fill up your character!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 14400, repeats: true)
        
        let request = UNNotificationRequest(identifier: "waterReminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Water reminder scheduled successfully.")
            }
        }
    }
    
    private func cancelWaterReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["waterReminder"])
        print("Water reminders cancelled.")
    }
}
