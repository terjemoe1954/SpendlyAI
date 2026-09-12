//
//  FinancialProfileSettingsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct FinancialProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]

    @State private var monthlyNetIncome = ""
    @State private var nextPayday = Date.now
    @State private var minimumBuffer = ""
    @State private var selectedCurrencyCode = "NOK"
    @State private var expenseDrafts: [ProfileExpenseDraft] = []
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
            expenseSection
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

    private var expenseSection: some View {
        Section("onboarding.expenses.section") {
            ForEach($expenseDrafts) { $expense in
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    TextField("onboarding.expense.name", text: $expense.name)
                    TextField("onboarding.expense.amount", text: $expense.amount)
                        .keyboardType(.decimalPad)
                    DatePicker("onboarding.expense.dueDate", selection: $expense.dueDate, displayedComponents: .date)
                }
            }
            .onDelete { indexSet in
                expenseDrafts.remove(atOffsets: indexSet)
            }

            Button {
                expenseDrafts.append(ProfileExpenseDraft())
            } label: {
                Label("onboarding.expense.add", systemImage: "plus")
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

        expenseDrafts = fixedExpenses.map { expense in
            ProfileExpenseDraft(
                name: expense.name,
                amount: expense.amount.description,
                dueDate: dateForDay(expense.dueDay)
            )
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

        for expense in fixedExpenses {
            modelContext.delete(expense)
        }

        for expense in expenseDrafts {
            guard let amount = decimalValue(from: expense.amount), !expense.name.isEmpty else {
                continue
            }

            modelContext.insert(FixedExpense(
                name: expense.name,
                amount: amount,
                dueDay: calendar.component(.day, from: expense.dueDate),
                category: .other,
                recurrence: .monthly,
                isActive: true
            ))
        }

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

    private func dateForDay(_ day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: .now)
        components.day = min(max(day, 1), 28)
        return calendar.date(from: components) ?? .now
    }

    private func decimalValue(from text: String) -> Decimal? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalizedText)
    }
}

private struct ProfileExpenseDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var dueDate = Date.now
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
