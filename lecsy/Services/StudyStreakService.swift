//
//  StudyStreakService.swift
//  lecsy
//
//  Created on 2026/02/24.
//

import Foundation
import Combine
// UNUserNotificationCenter は Sendable 未対応のため preconcurrency import で警告抑止
@preconcurrency import UserNotifications

@MainActor
class StudyStreakService: ObservableObject {
    static let shared = StudyStreakService()

    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var thisWeekLectures: Int = 0
    @Published var thisWeekMinutes: TimeInterval = 0

    private let activeDaysKey = "lecsy.activeDays"
    private let longestStreakKey = "lecsy.longestStreak"
    private let notificationScheduledKey = "lecsy.streakNotificationScheduled"

    private init() {
        loadStreak()
        calculateWeeklyStats()
    }

    // MARK: - Record Activity

    /// Call this when a lecture is recorded or reviewed
    func recordActivity() {
        var days = loadActiveDays()
        let today = dateKey(for: Date())

        if !days.contains(today) {
            days.append(today)
            saveActiveDays(days)
        }

        loadStreak()
        calculateWeeklyStats()
    }

    // MARK: - Streak Calculation

    private func loadStreak() {
        let days = Set(loadActiveDays())
        let calendar = Calendar.current
        var streak = 0
        var date = Date()

        // Check if today is active, if not check yesterday
        let todayKey = dateKey(for: date)
        if !days.contains(todayKey) {
            // Check yesterday - streak might still be alive
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? Date()
            if !days.contains(dateKey(for: date)) {
                currentStreak = 0
                return
            }
        }

        // Count consecutive days backwards
        while days.contains(dateKey(for: date)) {
            streak += 1
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? Date()
        }

        currentStreak = streak

        // Update longest streak
        let saved = UserDefaults.standard.integer(forKey: longestStreakKey)
        if streak > saved {
            longestStreak = streak
            UserDefaults.standard.set(streak, forKey: longestStreakKey)
        } else {
            longestStreak = saved
        }
    }

    private func calculateWeeklyStats() {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let lectures = LectureStore.shared.lectures.filter { $0.createdAt >= startOfWeek }

        thisWeekLectures = lectures.count
        thisWeekMinutes = lectures.reduce(0) { $0 + $1.duration } / 60
    }

    // MARK: - Notifications

    func scheduleStreakReminder() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Keep your streak alive!"
            content.body = "Record or review a lecture today to maintain your study streak."
            content.sound = .default

            // Schedule for 9 AM daily
            var dateComponents = DateComponents()
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "lecsy.streakReminder", content: content, trigger: trigger)

            center.add(request)
        }
    }

    func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["lecsy.streakReminder"])
    }

    // MARK: - Persistence Helpers

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func loadActiveDays() -> [String] {
        UserDefaults.standard.stringArray(forKey: activeDaysKey) ?? []
    }

    private func saveActiveDays(_ days: [String]) {
        // Keep only last 365 days to prevent unbounded growth
        let sorted = Array(Set(days)).sorted().suffix(365)
        UserDefaults.standard.set(Array(sorted), forKey: activeDaysKey)
    }
}
