//
//  SettingsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]

    @AppStorage(AppAppearance.storageKey) private var selectedAppearance = AppAppearance.system.rawValue
    @AppStorage(NotificationSettingsStorage.dailyReminderEnabledKey) private var dailyReminderEnabled = false
    @AppStorage(NotificationSettingsStorage.dailyReminderHourKey) private var dailyReminderHour = NotificationSettingsStorage.defaultReminderHour
    @AppStorage(NotificationSettingsStorage.dailyReminderMinuteKey) private var dailyReminderMinute = NotificationSettingsStorage.defaultReminderMinute
    @AppStorage(NotificationSettingsStorage.includeBudgetDetailsOnLockScreenKey) private var includeBudgetDetailsOnLockScreen = false

    @State private var notificationAlert: NotificationAlert?

    private let budgetService = BudgetService()
    private let notificationService = NotificationService()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    private var reminderTimeSignature: String {
        "\(dailyReminderHour):\(dailyReminderMinute)"
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appInformationSection
                appearanceSection
                notificationSection
            }
            .navigationTitle("tab.settings")
            .onChange(of: dailyReminderEnabled) { _, isEnabled in
                handleDailyReminderToggle(isEnabled)
            }
            .onChange(of: reminderTimeSignature) { _, _ in
                rescheduleDailyReminderIfNeeded()
            }
            .onChange(of: includeBudgetDetailsOnLockScreen) { _, _ in
                rescheduleDailyReminderIfNeeded()
            }
            .alert(
                notificationAlert?.titleKey ?? "settings.notifications.scheduleFailed.title",
                isPresented: Binding(
                    get: { notificationAlert != nil },
                    set: { isPresented in
                        if !isPresented {
                            notificationAlert = nil
                        }
                    }
                )
            ) {
                Button("common.ok", role: .cancel) {
                    notificationAlert = nil
                }
            } message: {
                if let notificationAlert {
                    Text(notificationAlert.messageKey)
                }
            }
        }
    }

    private var profileSection: some View {
        Section {
            NavigationLink {
                FinancialProfileSettingsView()
            } label: {
                Label("settings.profile", systemImage: "person.crop.circle")
            }
        }
    }

    private var appInformationSection: some View {
        Section {
            LabeledContent {
                Text("app.name")
            } label: {
                Text("settings.appName")
            }
            LabeledContent("settings.version", value: appVersion)
            LabeledContent("settings.build", value: buildNumber)
        }
    }

    private var appearanceSection: some View {
        Section("settings.appearance") {
            Picker("settings.appearance", selection: $selectedAppearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.titleKey)
                        .tag(appearance.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("settings.notifications.dailyReminder", isOn: $dailyReminderEnabled)

            if dailyReminderEnabled {
                DatePicker(
                    "settings.notifications.time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )

                Toggle(
                    "settings.notifications.lockScreenDetails",
                    isOn: $includeBudgetDetailsOnLockScreen
                )
            }
        } header: {
            Text("settings.notifications")
        } footer: {
            Text(includeBudgetDetailsOnLockScreen ? "settings.notifications.footer.detailsOn" : "settings.notifications.footer.detailsOff")
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = dailyReminderHour
            components.minute = dailyReminderMinute
            return Calendar.current.date(from: components) ?? .now
        } set: { newDate in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            dailyReminderHour = components.hour ?? NotificationSettingsStorage.defaultReminderHour
            dailyReminderMinute = components.minute ?? NotificationSettingsStorage.defaultReminderMinute
        }
    }

    private var currentBudgetContext: AIBudgetContext? {
        guard let profile = profiles.first else { return nil }

        let budgetInput = budgetService.makeInput(
            profile: profile,
            fixedExpenses: fixedExpenses,
            savingsGoals: savingsGoals,
            transactions: transactions
        )
        let budget = budgetService.calculateBudget(for: budgetInput)

        return AIBudgetContext(
            currencyCode: profile.currencyCode,
            safeToSpendToday: budget.recommendedDailyMaximum,
            spentToday: budget.spentToday,
            remainingToday: budget.remainingSafeAmountToday,
            daysUntilNextIncome: budget.daysRemaining,
            upcomingFixedExpenses: budget.upcomingFixedExpenses,
            plannedSavings: budget.plannedSavings,
            minimumBuffer: budget.minimumBuffer,
            isBudgetUnderPressure: budget.isNegativeBudget || budget.remainingSafeAmountToday < 0
        )
    }

    private func handleDailyReminderToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                let isAuthorized = await notificationService.requestAuthorization()

                guard isAuthorized else {
                    dailyReminderEnabled = false
                    notificationAlert = .permissionDenied
                    return
                }

                await scheduleDailyReminder()
            } else {
                notificationService.cancelDailyReminder()
            }
        }
    }

    private func rescheduleDailyReminderIfNeeded() {
        guard dailyReminderEnabled else { return }

        Task {
            await scheduleDailyReminder()
        }
    }

    private func scheduleDailyReminder() async {
        do {
            try await notificationService.scheduleDailyReminder(
                hour: dailyReminderHour,
                minute: dailyReminderMinute,
                context: currentBudgetContext,
                includeBudgetDetails: includeBudgetDetailsOnLockScreen
            )
        } catch {
            dailyReminderEnabled = false
            notificationAlert = .schedulingFailed
        }
    }
}

private enum NotificationAlert {
    case permissionDenied
    case schedulingFailed

    var titleKey: LocalizedStringKey {
        switch self {
        case .permissionDenied:
            "settings.notifications.permissionDenied.title"
        case .schedulingFailed:
            "settings.notifications.scheduleFailed.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .permissionDenied:
            "settings.notifications.permissionDenied.message"
        case .schedulingFailed:
            "settings.notifications.scheduleFailed.message"
        }
    }
}

#Preview {
    SettingsView()
}
