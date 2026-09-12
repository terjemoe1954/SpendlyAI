//
//  PrivacyAndSupportView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct PrivacyAndSupportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var transactions: [Transaction]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var dailyBudgetSnapshots: [DailyBudgetSnapshot]

    @AppStorage(NotificationSettingsStorage.dailyReminderEnabledKey) private var dailyReminderEnabled = false
    @AppStorage(NotificationSettingsStorage.dailyReminderHourKey) private var dailyReminderHour = NotificationSettingsStorage.defaultReminderHour
    @AppStorage(NotificationSettingsStorage.dailyReminderMinuteKey) private var dailyReminderMinute = NotificationSettingsStorage.defaultReminderMinute
    @AppStorage(NotificationSettingsStorage.includeBudgetDetailsOnLockScreenKey) private var includeBudgetDetailsOnLockScreen = false

    @State private var showsDeleteConfirmation = false
    @State private var dataDeletionAlert: DataDeletionAlert?

    private let notificationService = NotificationService()

    var body: some View {
        Form {
            Section("privacy.localData.title") {
                PrivacyInfoRow(
                    titleKey: "privacy.localData.minimized.title",
                    messageKey: "privacy.localData.minimized.message",
                    systemImage: "tray.full"
                )
                PrivacyInfoRow(
                    titleKey: "privacy.localData.localFirst.title",
                    messageKey: "privacy.localData.localFirst.message",
                    systemImage: "iphone"
                )
                PrivacyInfoRow(
                    titleKey: "privacy.localData.noBankCredentials.title",
                    messageKey: "privacy.localData.noBankCredentials.message",
                    systemImage: "key.slash"
                )
            }

            Section("privacy.ai.title") {
                PrivacyInfoRow(
                    titleKey: "privacy.ai.summaryOnly.title",
                    messageKey: "privacy.ai.summaryOnly.message",
                    systemImage: "sparkles"
                )
                PrivacyInfoRow(
                    titleKey: "privacy.ai.noHistory.title",
                    messageKey: "privacy.ai.noHistory.message",
                    systemImage: "list.bullet.clipboard"
                )
                PrivacyInfoRow(
                    titleKey: "privacy.ai.serverSecrets.title",
                    messageKey: "privacy.ai.serverSecrets.message",
                    systemImage: "lock.shield"
                )
            }

            Section("privacy.keychain.title") {
                Text("privacy.keychain.message")
                    .foregroundStyle(.secondary)
            }

            Section("privacy.policy.title") {
                Text("privacy.policy.message")
                    .foregroundStyle(.secondary)
            }

            Section("support.title") {
                PrivacyInfoRow(
                    titleKey: "support.feedback.title",
                    messageKey: "support.feedback.message",
                    systemImage: "questionmark.circle"
                )
                PrivacyInfoRow(
                    titleKey: "support.scope.title",
                    messageKey: "support.scope.message",
                    systemImage: "lifepreserver"
                )
            }

            Section {
                Button("privacy.delete.button", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            } footer: {
                Text("privacy.delete.footer")
            }
        }
        .navigationTitle("privacy.title")
        .confirmationDialog(
            "privacy.delete.confirmation.title",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("privacy.delete.confirmation.delete", role: .destructive) {
                deleteUserData()
            }
            Button("privacy.delete.confirmation.cancel", role: .cancel) { }
        } message: {
            Text("privacy.delete.confirmation.message")
        }
        .alert(
            dataDeletionAlert?.titleKey ?? "privacy.delete.success.title",
            isPresented: Binding(
                get: { dataDeletionAlert != nil },
                set: { isPresented in
                    if !isPresented {
                        dataDeletionAlert = nil
                    }
                }
            )
        ) {
            Button("common.ok", role: .cancel) {
                dataDeletionAlert = nil
            }
        } message: {
            if let dataDeletionAlert {
                Text(dataDeletionAlert.messageKey)
            }
        }
    }

    private func deleteUserData() {
        let modelsToDelete: [[any PersistentModel]] = [
            profiles,
            fixedExpenses,
            transactions,
            savingsGoals,
            dailyBudgetSnapshots
        ]

        for models in modelsToDelete {
            for model in models {
                modelContext.delete(model)
            }
        }

        dailyReminderEnabled = false
        dailyReminderHour = NotificationSettingsStorage.defaultReminderHour
        dailyReminderMinute = NotificationSettingsStorage.defaultReminderMinute
        includeBudgetDetailsOnLockScreen = false
        notificationService.cancelDailyReminder()

        do {
            try modelContext.save()
            dataDeletionAlert = .success
        } catch {
            dataDeletionAlert = .failure
        }
    }
}

private struct PrivacyInfoRow: View {
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(titleKey)
                    .font(.body.weight(.semibold))
                Text(messageKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppStyle.accentColor)
        }
    }
}

private enum DataDeletionAlert {
    case success
    case failure

    var titleKey: LocalizedStringKey {
        switch self {
        case .success:
            "privacy.delete.success.title"
        case .failure:
            "privacy.delete.failure.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .success:
            "privacy.delete.success.message"
        case .failure:
            "privacy.delete.failure.message"
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyAndSupportView()
    }
    .modelContainer(for: [
        UserFinancialProfile.self,
        FixedExpense.self,
        Transaction.self,
        SavingsGoal.self,
        DailyBudgetSnapshot.self
    ], inMemory: true)
}
