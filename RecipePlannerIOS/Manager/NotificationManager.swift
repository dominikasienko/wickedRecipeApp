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
    
    func toggleWaterReminders(isOn: Bool, locale: Locale = .autoupdatingCurrent) {
        toggleWaterReminders(
            isOn: isOn,
            intervalHours: 4,
            quietHoursEnabled: false,
            quietStartHour: 22,
            quietEndHour: 7,
            locale: locale
        )
    }
    
    func toggleWaterReminders(
        isOn: Bool,
        intervalHours: Int,
        quietHoursEnabled: Bool,
        quietStartHour: Int,
        quietEndHour: Int,
        locale: Locale = .autoupdatingCurrent
    ) {
        if isOn {
            Task {
                await requestAndScheduleReminders(
                    intervalHours: intervalHours,
                    quietHoursEnabled: quietHoursEnabled,
                    quietStartHour: quietStartHour,
                    quietEndHour: quietEndHour,
                    locale: locale
                )
            }
        } else {
            cancelWaterReminders()
        }
    }
    
    private func requestAndScheduleReminders(
        intervalHours: Int,
        quietHoursEnabled: Bool,
        quietStartHour: Int,
        quietEndHour: Int,
        locale: Locale
    ) async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("Notification permission granted.")
                scheduleWaterReminders(
                    intervalHours: intervalHours,
                    quietHoursEnabled: quietHoursEnabled,
                    quietStartHour: quietStartHour,
                    quietEndHour: quietEndHour,
                    locale: locale
                )
            } else {
                print("Notification permission denied.")
            }
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
        }
    }
    
    private func scheduleWaterReminders(
        intervalHours: Int,
        quietHoursEnabled: Bool,
        quietStartHour: Int,
        quietEndHour: Int,
        locale: Locale
    ) {
        let center = UNUserNotificationCenter.current()
        
        center.getPendingNotificationRequests { requests in
            let existingIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("waterReminder") }
            center.removePendingNotificationRequests(withIdentifiers: existingIDs)
            
            let safeInterval = max(1, min(intervalHours, 23))
            var allowedHours: [Int] = []
            
            for hour in stride(from: 0, through: 23, by: safeInterval) {
                if quietHoursEnabled && self.isHour(hour, inQuietRangeFrom: quietStartHour, to: quietEndHour) {
                    continue
                }
                allowedHours.append(hour)
            }
            
            if allowedHours.isEmpty {
                allowedHours = [12]
            }
            
            for hour in allowedHours {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Time to Hydrate!", locale: locale)
                content.body = String(
                    localized: "Don't forget to log your drinks and hydration progress.",
                    locale: locale
                )
                content.sound = .default
                
                var components = DateComponents()
                components.hour = hour
                components.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "waterReminder-\(hour)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification \(identifier): \(error.localizedDescription)")
                    }
                }
            }
            
            print("Water reminders scheduled for hours: \(allowedHours)")
        }
    }
    
    func cancelAllWaterReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("waterReminder") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .map { $0.request.identifier }
                .filter { $0.hasPrefix("waterReminder") }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func cancelWaterReminders() {
        cancelAllWaterReminders()
    }
    
    private func isHour(_ hour: Int, inQuietRangeFrom startHour: Int, to endHour: Int) -> Bool {
        let start = ((startHour % 24) + 24) % 24
        let end = ((endHour % 24) + 24) % 24
        
        if start == end {
            return true
        }
        
        if start < end {
            return hour >= start && hour < end
        }
        
        return hour >= start || hour < end
    }
}
