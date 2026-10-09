//
//  FinancialProfileSettingsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct FinancialProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserFinancialProfile.updatedAt, order: .reverse) private var profiles: [UserFinancialProfile]
    @Query private var savingsGoals: [SavingsGoal]

    @State private var selectedCurrencyCode = "NOK"
    @State private var savingsGoalName = ""
    @State private var savingsGoalAmount = ""
    @State private var savingsGoalDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var didLoadProfile = false
    @State private var saveAlert: SaveAlert?

    private let currencyCodes = ["NOK", "USD", "EUR", "THB"]

    var body: some View {
        Form {
            currencySection
            goalSection
        }
        .navigationTitle("settings.profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("settings.profile.save") {
                    saveChanges()
                }
            }
        }
        .task {
            loadProfileIfNeeded()
        }
        .alert(item: $saveAlert) { alert in
            switch alert {
            case .success:
                Alert(
                    title: Text("settings.profile.saved.title"),
                    message: Text("settings.profile.saved.message"),
                    dismissButton: .default(Text("common.ok"))
                )
            case .failure(let message):
                Alert(
                    title: Text("settings.profile.saveError.title"),
                    message: Text(message),
                    dismissButton: .default(Text("common.ok"))
                )
            }
        }
    }

    private var currencySection: some View {
        Section {
            Picker("onboarding.currency", selection: $selectedCurrencyCode) {
                ForEach(currencyCodes, id: \.self) { currencyCode in
                    Text(currencyCode)
                        .tag(currencyCode)
                }
            }
        }
    }

    private var goalSection: some View {
        Section("onboarding.goal.section") {
            TextField("onboarding.goal.name", text: $savingsGoalName)
            TextField("onboarding.goal.amount", text: $savingsGoalAmount)
                .keyboardType(.decimalPad)
            DatePicker("onboarding.goal.date", selection: $savingsGoalDate, displayedComponents: .date)
        }
    }

    private func loadProfileIfNeeded() {
        guard !didLoadProfile else { return }
        didLoadProfile = true

        if let profile = profiles.first {
            selectedCurrencyCode = profile.currencyCode
        }

        if let savingsGoal = savingsGoals.first {
            savingsGoalName = savingsGoal.name
            savingsGoalAmount = savingsGoal.targetAmount.description
            savingsGoalDate = savingsGoal.targetDate
        }
    }

    private func saveChanges() {
        let now = Date.now
        let profile = profiles.first ?? UserFinancialProfile()

        if profiles.isEmpty {
            modelContext.insert(profile)
            profile.createdAt = now
        }

        profile.monthlyNetIncome = 0
        profile.budgetPeriodStart = now
        profile.budgetPeriodEnd = now
        profile.currencyCode = selectedCurrencyCode
        profile.minimumBuffer = 0
        profile.updatedAt = now

        for savingsGoal in savingsGoals {
            modelContext.delete(savingsGoal)
        }

        if let targetAmount = decimalValue(from: savingsGoalAmount), !savingsGoalName.isEmpty {
            modelContext.insert(SavingsGoal(
                name: savingsGoalName,
                targetAmount: targetAmount,
                targetDate: savingsGoalDate,
                savedAmount: 0,
                priority: .medium
            ))
        }

        do {
            try modelContext.save()
            saveAlert = .success
        } catch {
            saveAlert = .failure(error.localizedDescription)
        }
    }

    private func decimalValue(from text: String) -> Decimal? {
        MoneyParser.decimal(from: text)
    }

    private enum SaveAlert: Identifiable {
        case success
        case failure(String)

        var id: String {
            switch self {
            case .success:
                "success"
            case .failure:
                "failure"
            }
        }
    }
}

#Preview {
    NavigationStack {
        FinancialProfileSettingsView()
    }
    .modelContainer(for: [
        UserFinancialProfile.self,
        FixedExpense.self,
        Transaction.self,
        SavingsGoal.self,
        DailyBudgetSnapshot.self
    ], inMemory: true)
}
