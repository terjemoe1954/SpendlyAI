//
//  AIView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct AIView: View {
    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]

    @State private var viewModel = AIViewModel()

    private let budgetService = BudgetService()

    private var budgetContext: AIBudgetContext? {
        guard let profile = profiles.first else { return nil }
        let input = budgetService.makeInput(
            profile: profile,
            fixedExpenses: fixedExpenses,
            savingsGoals: savingsGoals,
            transactions: transactions
        )
        let result = budgetService.calculateBudget(for: input)

        return AIBudgetContext(
            currencyCode: profile.currencyCode,
            safeToSpendToday: result.recommendedDailyMaximum,
            spentToday: result.spentToday,
            remainingToday: result.remainingSafeAmountToday,
            daysUntilNextIncome: result.daysRemaining,
            upcomingFixedExpenses: result.upcomingFixedExpenses,
            plannedSavings: result.plannedSavings,
            minimumBuffer: result.minimumBuffer,
            isBudgetUnderPressure: result.isNegativeBudget
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    answerSection
                    questionSection
                    examplesSection
                    privacySection
                }
                .padding(AppSpacing.large)
            }
            .background(AppStyle.screenBackground)
            .navigationTitle("tab.ai")
        }
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("ai.answer.title", systemImage: "sparkles")
                .font(.headline)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(viewModel.answer)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if viewModel.lastError != nil {
                Text("ai.fallback.notice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("ai.question.title")
                .font(.headline)

            TextField("ai.question.placeholder", text: $viewModel.question, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button {
                Task {
                    await viewModel.ask(using: budgetContext)
                }
            } label: {
                Label("ai.ask", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canAsk)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("ai.examples.title")
                .font(.headline)

            ForEach(exampleQuestionKeys, id: \.self) { questionKey in
                Button {
                    viewModel.question = localizedString(for: questionKey)
                    Task {
                        await viewModel.ask(using: budgetContext)
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(questionKey))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(AppSpacing.medium)
                .background(AppStyle.screenBackground, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Label("ai.privacy.title", systemImage: "lock")
                .font(.headline)

            Text("ai.privacy.message")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var exampleQuestionKeys: [String] {
        [
            "ai.example.eatOut",
            "ai.example.spendAmount",
            "ai.example.goal",
            "ai.example.weekend",
            "ai.example.lowerBudget"
        ]
    }

    private func localizedString(for key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}

#Preview {
    AIView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
