//
//  GoalsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var goals: [SavingsGoal]
    @Query private var transactions: [Transaction]

    @State private var showsNewGoal = false
    @State private var editingGoal: SavingsGoal?

    private let budgetService = BudgetService()
    private let goalPlanningService = GoalPlanningService()

    private var currencyCode: String {
        profiles.first?.currencyCode ?? "NOK"
    }

    private var activeGoals: [SavingsGoal] {
        sortedGoals.filter { !$0.isCompleted }
    }

    private var completedGoals: [SavingsGoal] {
        sortedGoals.filter(\.isCompleted)
    }

    private var sortedGoals: [SavingsGoal] {
        goals.sorted { first, second in
            if first.isCompleted != second.isCompleted {
                return !first.isCompleted
            }

            if first.priority != second.priority {
                return first.priority.rawValue > second.priority.rawValue
            }

            return first.targetDate < second.targetDate
        }
    }

    private var budgetResult: BudgetResult? {
        guard let profile = profiles.first else { return nil }
        let input = budgetService.makeInput(
            profile: profile,
            fixedExpenses: fixedExpenses,
            savingsGoals: activeGoals,
            transactions: transactions
        )
        return budgetService.calculateBudget(for: input)
    }

    var body: some View {
        NavigationStack {
            List {
                if goals.isEmpty {
                    emptyState
                }

                if !activeGoals.isEmpty {
                    Section("goals.active") {
                        ForEach(activeGoals) { goal in
                            goalRow(goal, isCompleted: false)
                        }
                    }
                }

                if !completedGoals.isEmpty {
                    Section("goals.completed") {
                        ForEach(completedGoals) { goal in
                            goalRow(goal, isCompleted: true)
                        }
                    }
                }
            }
            .navigationTitle("tab.goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsNewGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("goal.add")
                }
            }
            .sheet(isPresented: $showsNewGoal) {
                GoalEditorView()
            }
            .sheet(item: $editingGoal) { goal in
                GoalEditorView(goal: goal)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Label("goals.empty.title", systemImage: "target")
                .font(.headline)

            Text("goals.empty.message")
                .foregroundStyle(.secondary)

            Button {
                showsNewGoal = true
            } label: {
                Label("goal.add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.medium)
    }

    private func goalRow(_ goal: SavingsGoal, isCompleted: Bool) -> some View {
        let plan = goalPlanningService.plan(for: goal)
        let insight = insightMessage(for: goal, plan: plan)

        return GoalRowView(
            goal: goal,
            plan: plan,
            currencyCode: currencyCode,
            insightMessage: insight,
            isCompleted: isCompleted,
            onEdit: {
                editingGoal = goal
            },
            onComplete: {
                markCompleted(goal)
            }
        )
        .swipeActions(edge: .trailing) {
            Button("goal.edit") {
                editingGoal = goal
            }
            .tint(AppStyle.accentColor)

            if !isCompleted {
                Button("goal.markComplete") {
                    markCompleted(goal)
                }
                .tint(.green)
            }
        }
    }

    private func markCompleted(_ goal: SavingsGoal) {
        goal.savedAmount = max(goal.savedAmount, goal.targetAmount)
        goal.isCompleted = true
        try? modelContext.save()
    }

    private func insightMessage(for goal: SavingsGoal, plan: GoalPlan) -> String {
        let weeklyAmount = formattedCurrency(plan.weeklySavingsNeeded, currencyCode: currencyCode)

        guard let budgetResult else {
            return String(
                format: String(localized: "goals.aiInsight.noBudget"),
                weeklyAmount
            )
        }

        let remainingToday = formattedCurrency(max(budgetResult.remainingSafeAmountToday, 0), currencyCode: currencyCode)
        return String(
            format: String(localized: "goals.aiInsight.withBudget"),
            weeklyAmount,
            remainingToday
        )
    }

    private func formattedCurrency(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? amount.description
    }
}

private struct GoalRowView: View {
    let goal: SavingsGoal
    let plan: GoalPlan
    let currencyCode: String
    let insightMessage: String
    let isCompleted: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void

    @ScaledMetric(relativeTo: .body) private var gaugeSize: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                Gauge(value: plan.progress, in: 0...1) {
                    Text("goal.progress")
                } currentValueLabel: {
                    Text(plan.progress.formatted(.percent.precision(.fractionLength(0))))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(isCompleted ? .green : AppStyle.accentColor)
                .frame(width: gaugeSize, height: gaugeSize)

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(goal.name)
                            .font(.headline)

                        Spacer()

                        if isCompleted {
                            Label("goal.completedBadge", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }

                    Text(goal.targetDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(goal.priority.titleKey)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            GoalMetricGrid(plan: plan, currencyCode: currencyCode)

            Label("goals.aiInsight.title", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))

            Text(verbatim: insightMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("goal.edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)

                if !isCompleted {
                    Button("goal.markComplete") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.small)
    }
}

private struct GoalMetricGrid: View {
    let plan: GoalPlan
    let currencyCode: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: AppSpacing.medium, verticalSpacing: AppSpacing.small) {
            GridRow {
                metric("goal.remaining", value: formattedCurrency(plan.remainingAmount))
                metric("goal.weeklyNeeded", value: formattedCurrency(plan.weeklySavingsNeeded))
            }

            GridRow {
                metric("goal.monthlyNeeded", value: formattedCurrency(plan.monthlySavingsNeeded))
                metric("goal.daysRemaining", value: plan.daysRemaining.formatted())
            }
        }
    }

    private func metric(_ titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? amount.description
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
