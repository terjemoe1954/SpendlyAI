//
//  FinancialProfileSettingsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct FinancialProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserFinancialProfile]
    @Query private var savingsGoals: [SavingsGoal]

    @State private var monthlyNetIncome = ""
    @State private var nextPayday = Date.now
    @State private var minimumBuffer = ""
    @State private var selectedCurrencyCode = "NOK"
    @State private var savingsGoalName = ""
    @State private var savingsGoalAmount = ""
    @State private var savingsGoalDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var didLoadProfile = false

    private let currencyCodes = ["NOK", "USD", "EUR", "THB"]

    private var canSave: Bool {
        decimalValue(from: monthlyNetIncome) != nil && decimalValue(from: minimumBuffer) != nil
    }

    var body: some View {
        Form {
            incomeSection
            bufferSection
            goalSection
        }
        .navigationTitle("settings.profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("settings.profile.save") {
                    saveChanges()
                }
                .disabled(!canSave)
            }
        }
        .task {
            loadProfileIfNeeded()
        }
    }

    private var incomeSection: some View {
        Section("onboarding.income.section") {
            TextField("onboarding.monthlyIncome", text: $monthlyNetIncome)
                .keyboardType(.decimalPad)

            DatePicker("onboarding.nextPayday", selection: $nextPayday, displayedComponents: .date)

            Picker("onboarding.currency", selection: $selectedCurrencyCode) {
                ForEach(currencyCodes, id: \.self) { currencyCode in
                    Text(currencyCode)
                        .tag(currencyCode)
                }
            }
        }
    }

    private var bufferSection: some View {
        Section("onboarding.buffer.section") {
            TextField("onboarding.minimumBuffer", text: $minimumBuffer)
                .keyboardType(.decimalPad)
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
            monthlyNetIncome = profile.monthlyNetIncome.description
            nextPayday = profile.budgetPeriodEnd
            minimumBuffer = profile.minimumBuffer.description
            selectedCurrencyCode = profile.currencyCode
        }

        if let savingsGoal = savingsGoals.first {
            savingsGoalName = savingsGoal.name
            savingsGoalAmount = savingsGoal.targetAmount.description
            savingsGoalDate = savingsGoal.targetDate
        }
    }

    private func saveChanges() {
        guard let income = decimalValue(from: monthlyNetIncome),
              let buffer = decimalValue(from: minimumBuffer) else {
            return
        }

        let calendar = Calendar.current
        let now = Date.now
        let profile = profiles.first ?? UserFinancialProfile()

        if profiles.isEmpty {
            modelContext.insert(profile)
            profile.createdAt = now
        }

        profile.monthlyNetIncome = income
        profile.paydayDay = calendar.component(.day, from: nextPayday)
        profile.budgetPeriodStart = now
        profile.budgetPeriodEnd = nextPayday
        profile.currencyCode = selectedCurrencyCode
        profile.minimumBuffer = buffer
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
    }

    private func decimalValue(from text: String) -> Decimal? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalizedText)
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
