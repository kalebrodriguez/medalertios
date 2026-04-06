//
//  Item.swift
//  MedAlert
//
//  Created by Kaleb Rodriguez on 3/29/26.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - Enums

enum FrequencyType: String, Codable, CaseIterable {
    case daily = "Daily"
    case twiceDaily = "Twice Daily"
    case threeTimesDaily = "3x Daily"
    case weekly = "Weekly"
    case asNeeded = "As Needed"

    var timesPerDay: Int {
        switch self {
        case .daily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .weekly: return 1
        case .asNeeded: return 0
        }
    }
}

// MARK: - Model

@Model
final class Medication {
    var name: String
    var dosage: String
    var frequencyRaw: String
    var notes: String
    var isActive: Bool
    var colorName: String
    var createdAt: Date
    var scheduledTimes: [Date]
    var lastTakenAt: Date?

    var frequency: FrequencyType {
        get { FrequencyType(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var nextScheduledTime: Date? {
        guard frequency != .asNeeded, !scheduledTimes.isEmpty else { return nil }
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        for time in scheduledTimes.sorted() {
            let c = cal.dateComponents([.hour, .minute], from: time)
            if let t = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today), t > now {
                return t
            }
        }
        if let tom = cal.date(byAdding: .day, value: 1, to: today),
           let first = scheduledTimes.sorted().first {
            let c = cal.dateComponents([.hour, .minute], from: first)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: tom)
        }
        return nil
    }

    var isDueNow: Bool {
        guard let next = nextScheduledTime else { return false }
        return next.timeIntervalSinceNow <= 0 && next.timeIntervalSinceNow > -3600
    }

    init(
        name: String = "",
        dosage: String = "",
        frequency: FrequencyType = .daily,
        scheduledTimes: [Date] = [],
        notes: String = "",
        isActive: Bool = true,
        colorName: String = "blue"
    ) {
        self.name = name
        self.dosage = dosage
        self.frequencyRaw = frequency.rawValue
        self.scheduledTimes = scheduledTimes
        self.notes = notes
        self.isActive = isActive
        self.colorName = colorName
        self.createdAt = Date()
    }
}

// MARK: - Color Extension

extension String {
    var medColor: Color {
        switch self {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .blue
        }
    }
}

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]) { _, _ in }
    }

    func schedule(for med: Medication) {
        guard med.isActive else { return }
        let center = UNUserNotificationCenter.current()
        for (i, time) in med.scheduledTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Time to take \(med.name)"
            content.body = med.dosage.isEmpty
                ? "Don't forget your medication!"
                : "Dose: \(med.dosage)"
            content.sound = .default
            var c = Calendar.current.dateComponents([.hour, .minute], from: time)
            c.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
            let req = UNNotificationRequest(
                identifier: "med-\(med.name)-\(i)",
                content: content,
                trigger: trigger
            )
            center.add(req, withCompletionHandler: nil)
        }
    }

    func cancel(for med: Medication) {
        let ids = med.scheduledTimes.indices.map { "med-\(med.name)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
