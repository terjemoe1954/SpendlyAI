//
//  DashboardView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]

    @State private var showsNewTransaction = false

    private let budgetService = BudgetService()
    private let dailyInsightService = DailyInsightService()

    private var profile: UserFinancialProfile? {
        profiles.first
    }

    private var budgetResult: BudgetResult? {
        guard let profile else { return nil }
        let input = budgetService.makeInput(
            profile: profile,
            fixedExpenses: fixedExpenses,
            savingsGoals: savingsGoals,
            transactions: transactions
        )
        return budgetService.calculateBudget(for: input)
    }

    private var primarySavingsGoal: SavingsGoal? {
        savingsGoals.sorted { first, second in
            if first.priority != second.priority {
                return first.priority.rawValue > second.priority.rawValue
            }
            return first.targetDate < second.targetDate
        }.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    if let profile, let budgetResult {
                        safeToSpendCard(profile: profile, budgetResult: budgetResult)
                        metricsGrid(budgetResult: budgetResult, currencyCode: profile.currencyCode)
                        upcomingExpensesSection(currencyCode: profile.currencyCode)
                        savingsGoalSection(currencyCode: profile.currencyCode)
                        insightSection(profile: profile, budgetResult: budgetResult)
                    }
                }
                .padding(AppSpacing.large)
            }
            .background(AppStyle.screenBackground)
            .navigationTitle("tab.home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsNewTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                    }
                    .accessibilityLabel("dashboard.addPurchase")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showsNewTransaction = true
                } label: {
                    Label("dashboard.addPurchase", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(AppSpacing.large)
                .background(.bar)
            }
            .sheet(isPresented: $showsNewTransaction) {
                TransactionEditorView()
            }
        }
    }

    private func safeToSpendCard(profile: UserFinancialProfile, budgetResult: BudgetResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("dashboard.safeToSpend.title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(formattedCurrency(budgetResult.recommendedDailyMaximum, currencyCode: profile.currencyCode))
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .contentTransition(.numericText())

                Text("dashboard.safeToSpend.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Gauge(
                value: gaugeValue(for: budgetResult),
                in: 0...1
            ) {
                Text("dashboard.gauge.label")
            } currentValueLabel: {
                Text(formattedCurrency(max(budgetResult.remainingSafeAmountToday, 0), currencyCode: profile.currencyCode))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(budgetResult.isNegativeBudget ? .red : AppStyle.accentColor)
            .frame(maxWidth: .infinity)

            if budgetResult.isNegativeBudget {
                Label("dashboard.warning", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricsGrid(budgetResult: BudgetResult, currencyCode: String) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.medium) {
            DashboardMetricView(
                titleKey: "dashboard.spentToday",
                value: formattedCurrency(budgetResult.spentToday, currencyCode: currencyCode),
                systemImage: "cart"
            )
            DashboardMetricView(
                titleKey: "dashboard.leftToday",
                value: formattedCurrency(budgetResult.remainingSafeAmountToday, currencyCode: currencyCode),
                systemImage: "wallet.pass"
            )
            DashboardMetricView(
                titleKey: "dashboard.daysToIncome",
                value: budgetResult.daysRemaining.formatted(),
                systemImage: "calendar"
            )
            DashboardMetricView(
                titleKey: "dashboard.fixedExpensesTotal",
                value: formattedCurrency(budgetResult.upcomingFixedExpenses, currencyCode: currencyCode),
                systemImage: "doc.text"
            )
        }
    }

    private func upcomingExpensesSection(currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("dashboard.upcomingExpenses")
                .font(.headline)

            let activeExpenses = fixedExpenses.filter(\.isActive).prefix(3)
            if activeExpenses.isEmpty {
                Text("dashboard.upcomingExpenses.empty")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.medium)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(Array(activeExpenses)) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.name)
                                .font(.body.weight(.medium))
                            HStack(spacing: 4) {
                                Text("dashboard.dueDay")
                                Text(expense.dueDay.formatted())
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formattedCurrency(expense.amount, currencyCode: currencyCode))
                            .font(.body.weight(.semibold))
                    }
                    .padding(AppSpacing.medium)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func savingsGoalSection(currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("dashboard.primaryGoal")
                .font(.headline)

            if let primarySavingsGoal {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(primarySavingsGoal.name)
                            .font(.body.weight(.medium))

                        Spacer()

                        Text(formattedCurrency(primarySavingsGoal.savedAmount, currencyCode: currencyCode))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: savingsProgress(for: primarySavingsGoal))
                        .tint(AppStyle.accentColor)

                    Text(formattedCurrency(primarySavingsGoal.targetAmount, currencyCode: currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(AppSpacing.medium)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("dashboard.primaryGoal.empty")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.medium)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func insightSection(profile: UserFinancialProfile, budgetResult: BudgetResult) -> some View {
        let insight = dailyInsightService.makeInsight(from: AIBudgetContext(
            currencyCode: profile.currencyCode,
            safeToSpendToday: budgetResult.recommendedDailyMaximum,
            spentToday: budgetResult.spentToday,
            remainingToday: budgetResult.remainingSafeAmountToday,
            daysUntilNextIncome: budgetResult.daysRemaining,
            upcomingFixedExpenses: budgetResult.upcomingFixedExpenses,
            plannedSavings: budgetResult.plannedSavings,
            minimumBuffer: budgetResult.minimumBuffer,
            isBudgetUnderPressure: budgetResult.isNegativeBudget
        ))

        return VStack(alignment: .leading, spacing: AppSpacing.small) {
            Label("dashboard.insight.title", systemImage: "sparkles")
                .font(.headline)

            Text(verbatim: insight.message)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formattedCurrency(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? amount.description
    }

    private func savingsProgress(for goal: SavingsGoal) -> Double {
        guard goal.targetAmount > 0 else { return 0 }
        let progress = (goal.savedAmount as NSDecimalNumber).doubleValue / (goal.targetAmount as NSDecimalNumber).doubleValue
        return min(max(progress, 0), 1)
    }

    private func gaugeValue(for budgetResult: BudgetResult) -> Double {
        guard budgetResult.recommendedDailyMaximum > 0 else { return 0 }
        let remaining = max(budgetResult.remainingSafeAmountToday, 0)
        let value = (remaining as NSDecimalNumber).doubleValue / (budgetResult.recommendedDailyMaximum as NSDecimalNumber).doubleValue
        return min(max(value, 0), 1)
    }
}

private struct DashboardMetricView: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(AppStyle.accentColor)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
