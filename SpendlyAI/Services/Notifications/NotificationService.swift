//
//  NotificationService.swift
//  SpendlyAI
//

import Foundation
import UserNotifications

enum NotificationSettingsStorage {
    static let dailyReminderEnabledKey = "dailyReminderEnabled"
    static let dailyReminderHourKey = "dailyReminderHour"
    static let dailyReminderMinuteKey = "dailyReminderMinute"
    static let includeBudgetDetailsOnLockScreenKey = "includeBudgetDetailsOnLockScreen"

    static let defaultReminderHour = 8
    static let defaultReminderMinute = 0
}

struct DailyReminderNotificationContent: Equatable {
    let title: String
    let body: String
}

struct NotificationService {
    static let dailyReminderIdentifier = "daily-budget-reminder"

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        context: AIBudgetContext?,
        includeBudgetDetails: Bool
    ) async throws {
        cancelDailyReminder()

        let reminderContent = makeDailyReminderContent(
            context: context,
            includeBudgetDetails: includeBudgetDetails
        )
        let content = UNMutableNotificationContent()
        content.title = reminderContent.title
        content.body = reminderContent.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = min(max(hour, 0), 23)
        dateComponents.minute = min(max(minute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
    }

    func makeDailyReminderContent(
        context: AIBudgetContext?,
        includeBudgetDetails: Bool,
        locale: Locale = .current
    ) -> DailyReminderNotificationContent {
        let title = String(localized: "notification.daily.title")

        guard includeBudgetDetails, let context else {
            return DailyReminderNotificationContent(
                title: title,
                body: String(localized: "notification.daily.body.generic")
            )
        }

        let remainingToday = formattedCurrency(
            max(context.remainingToday, 0),
            currencyCode: context.currencyCode,
            locale: locale
        )

        return DailyReminderNotificationContent(
            title: title,
            body: String(
                format: String(localized: "notification.daily.body.detail"),
                remainingToday
            )
        )
    }

    private func formattedCurrency(_ amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? amount.description
    }
}
