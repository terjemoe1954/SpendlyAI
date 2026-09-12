//
//  OnboardingView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var monthlyNetIncome = ""
    @State private var nextPayday = Date.now
    @State private var minimumBuffer = ""
    @State private var selectedCurrencyCode = "NOK"
    @State private var fixedExpenses: [FixedExpenseDraft] = []
    @State private var savingsGoalName = ""
    @State private var savingsGoalAmount = ""
    @State private var savingsGoalDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now

    private let currencyCodes = ["NOK", "USD", "EUR", "THB"]

    private var canSave: Bool {
        decimalValue(from: monthlyNetIncome) != nil && decimalValue(from: minimumBuffer) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                welcomeSection
                incomeSection
                expenseSection
                bufferSection
                goalSection
                summarySection
            }
            .navigationTitle("onboarding.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("onboarding.save") {
                        saveProfile()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var welcomeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("onboarding.welcome.title")
                    .font(.title2.bold())

                Text("onboarding.welcome.message")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.small)
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
            ForEach($fixedExpenses) { $expense in
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    TextField("onboarding.expense.name", text: $expense.name)
                    TextField("onboarding.expense.amount", text: $expense.amount)
                        .keyboardType(.decimalPad)
                    DatePicker("onboarding.expense.dueDate", selection: $expense.dueDate, displayedComponents: .date)
                }
            }
            .onDelete { indexSet in
                fixedExpenses.remove(atOffsets: indexSet)
            }

            Button {
                fixedExpenses.append(FixedExpenseDraft())
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

    private var summarySection: some View {
        Section("onboarding.summary.section") {
            LabeledContent("onboarding.summary.currency", value: selectedCurrencyCode)
            LabeledContent("onboarding.summary.expenses", value: fixedExpenses.count.formatted())
        }
    }

    private func saveProfile() {
        guard let income = decimalValue(from: monthlyNetIncome),
              let buffer = decimalValue(from: minimumBuffer) else {
            return
        }

        let calendar = Calendar.current
        let now = Date.now
        let paydayDay = calendar.component(.day, from: nextPayday)

        let profile = UserFinancialProfile(
            monthlyNetIncome: income,
            paydayDay: paydayDay,
            budgetPeriodStart: now,
            budgetPeriodEnd: nextPayday,
            currencyCode: selectedCurrencyCode,
            minimumBuffer: buffer,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(profile)

        for expense in fixedExpenses {
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

private struct FixedExpenseDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var dueDate = Date.now
}

#Preview {
    OnboardingView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
