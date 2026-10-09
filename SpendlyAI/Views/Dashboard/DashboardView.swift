import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \UserFinancialProfile.updatedAt, order: .reverse) private var profiles: [UserFinancialProfile]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]

    @State private var showsNewTransaction = false
    @State private var selectedPeriod: DashboardPeriod = .thisMonth
    @State private var customStartDate = Calendar.current.date(
        byAdding: .month,
        value: -1,
        to: .now
    ) ?? .now
    @State private var customEndDate = Date.now

    private let budgetService = BudgetService()
    private let dailyInsightService = DailyInsightService()

    private var profile: UserFinancialProfile? {
        profiles.first
    }

    private var currencyCode: String {
        profile?.currencyCode ?? Locale.current.currency?.identifier ?? "NOK"
    }

    private var selectedInterval: DateInterval {
        selectedPeriod.interval(
            customStartDate: customStartDate,
            customEndDate: customEndDate
        )
    }

    private var summary: DashboardPeriodSummary {
        DashboardSummaryCalculator().summary(
            transactions: transactions,
            incomes: incomes,
            fixedExpenses: fixedExpenses,
            interval: selectedInterval
        )
    }

    private var budgetResult: BudgetResult? {
        guard let profile else { return nil }
        return budgetService.calculateBudget(for: budgetService.makeInput(
            profile: profile,
            fixedExpenses: fixedExpenses,
            savingsGoals: savingsGoals,
            transactions: transactions,
            incomes: incomes
        ))
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
                    periodSection
                    metricsGrid
                    upcomingExpensesSection
                    savingsGoalSection
                    if let profile, let budgetResult {
                        insightSection(profile: profile, budgetResult: budgetResult)
                    }
                }
                .padding(AppSpacing.large)
            }
            .background(AppStyle.screenBackground)
            .navigationTitle("Spendly AI")
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

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Label("dashboard.period", systemImage: "calendar")
                    .font(.headline)

                Spacer()

                Picker("dashboard.period", selection: $selectedPeriod) {
                    ForEach(DashboardPeriod.allCases) { period in
                        Text(period.titleKey).tag(period)
                    }
                }
                .pickerStyle(.menu)
            }

            if selectedPeriod == .custom {
                DatePicker(
                    "filter.from",
                    selection: $customStartDate,
                    in: ...customEndDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "filter.to",
                    selection: $customEndDate,
                    in: customStartDate...,
                    displayedComponents: .date
                )
            }

            HStack(spacing: 4) {
                Text(selectedInterval.start, format: .dateTime.day().month(.wide).year())
                Text(verbatim: "–")
                Text(
                    selectedInterval.end.addingTimeInterval(-1),
                    format: .dateTime.day().month(.wide).year()
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppSpacing.medium
        ) {
            DashboardMetricView(
                titleKey: "statistics.income",
                value: formattedCurrency(summary.totalIncome),
                systemImage: "arrow.down.circle",
                color: AppStyle.accentColor
            )
            DashboardMetricView(
                titleKey: "statistics.expenses",
                value: formattedCurrency(summary.totalExpenses),
                systemImage: "arrow.up.circle",
                color: .red
            )
            DashboardMetricView(
                titleKey: "dashboard.receivable",
                value: formattedCurrency(summary.receivableIncome),
                systemImage: "clock.arrow.circlepath",
                color: .orange
            )
            DashboardMetricView(
                titleKey: "statistics.net",
                value: formattedCurrency(summary.totalIncome - summary.totalExpenses),
                systemImage: "equal.circle",
                color: summary.totalIncome >= summary.totalExpenses
                    ? AppStyle.accentColor
                    : .red
            )
            DashboardMetricView(
                titleKey: "dashboard.daysToIncome",
                value: summary.daysUntilNextIncome.formatted(),
                systemImage: "calendar",
                color: AppStyle.accentColor
            )
            DashboardMetricView(
                titleKey: "dashboard.entryCount",
                value: summary.entryCount.formatted(),
                systemImage: "list.number",
                color: AppStyle.accentColor
            )
        }
    }

    private var upcomingExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("dashboard.upcomingExpenses")
                .font(.headline)

            let activeExpenses = fixedExpenses
                .filter(\.isActive)
                .sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
                .prefix(3)

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
                            Text(nextDueDate(for: expense), format: .dateTime.day().month(.wide).year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formattedCurrency(expense.amount))
                            .font(.body.weight(.semibold))
                    }
                    .padding(AppSpacing.medium)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            NavigationLink {
                FixedExpensesView()
            } label: {
                Label("fixedExpenses.manage", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var savingsGoalSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("dashboard.primaryGoal")
                .font(.headline)

            if let primarySavingsGoal {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(primarySavingsGoal.name)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(formattedCurrency(primarySavingsGoal.savedAmount))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: savingsProgress(for: primarySavingsGoal))
                        .tint(AppStyle.accentColor)
                    Text(formattedCurrency(primarySavingsGoal.targetAmount))
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

    private func nextDueDate(for expense: FixedExpense, from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        var occurrence = expense.dueDate.map { calendar.startOfDay(for: $0) }
            ?? calendar.date(
                bySetting: .day,
                value: min(max(expense.dueDay, 1), 28),
                of: today
            )
            ?? today

        if expense.dueDate == nil, occurrence < today {
            occurrence = calendar.date(byAdding: .month, value: 1, to: occurrence) ?? occurrence
        }

        while occurrence < today {
            guard let next = DashboardSummaryCalculator(calendar: calendar).nextExpenseDate(
                after: occurrence,
                expense: expense
            ), next > occurrence else { break }
            occurrence = next
        }
        return occurrence
    }

    private func savingsProgress(for goal: SavingsGoal) -> Double {
        guard goal.targetAmount > 0 else { return 0 }
        let saved = (goal.savedAmount as NSDecimalNumber).doubleValue
        let target = (goal.targetAmount as NSDecimalNumber).doubleValue
        return min(max(saved / target, 0), 1)
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        MoneyFormatter.string(from: amount, currencyCode: currencyCode)
    }
}

private enum DashboardPeriod: String, CaseIterable, Identifiable {
    case previousMonth
    case thisMonth
    case nextMonth
    case thisYear
    case custom

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .previousMonth: "filter.period.previousMonth"
        case .thisMonth: "filter.period.thisMonth"
        case .nextMonth: "filter.period.nextMonth"
        case .thisYear: "filter.period.thisYear"
        case .custom: "filter.period.custom"
        }
    }

    func interval(
        customStartDate: Date,
        customEndDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval {
        switch self {
        case .previousMonth:
            let date = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: date)
                ?? DateInterval(start: date, duration: 1)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
                ?? DateInterval(start: now, duration: 1)
        case .nextMonth:
            let date = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: date)
                ?? DateInterval(start: date, duration: 1)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
                ?? DateInterval(start: now, duration: 1)
        case .custom:
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let lastDay = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: start, end: end)
        }
    }
}

private struct DashboardPeriodSummary {
    var totalIncome = Decimal.zero
    var totalExpenses = Decimal.zero
    var receivableIncome = Decimal.zero
    var entryCount = 0
    var daysUntilNextIncome = 0
}

private struct DashboardSummaryCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func nextExpenseDate(after date: Date, expense: FixedExpense) -> Date? {
        nextExpenseOccurrence(
            after: date,
            recurrence: expense.recurrence,
            customMonths: expense.customRecurrenceMonths
        )
    }

    func summary(
        transactions: [Transaction],
        incomes: [Income],
        fixedExpenses: [FixedExpense],
        interval: DateInterval,
        now: Date = .now
    ) -> DashboardPeriodSummary {
        var result = DashboardPeriodSummary()
        result.daysUntilNextIncome = daysUntilNextIncome(
            incomes: incomes,
            now: now
        )

        for transaction in transactions {
            let date = transaction.dueDate ?? transaction.date
            guard interval.contains(date) else { continue }
            result.totalExpenses += transaction.amount
            result.entryCount += 1
        }

        for income in incomes where income.isActive {
            let occurrences = incomeOccurrences(for: income, interval: interval)
            for occurrence in occurrences {
                result.totalIncome += income.amount
                result.entryCount += 1

                let isOriginalOccurrence = calendar.isDate(
                    occurrence,
                    inSameDayAs: income.dueDate ?? income.date
                )
                let status = isOriginalOccurrence
                    ? income.effectivePaymentStatus(now: now, calendar: calendar)
                    : PaymentStatus.pending.effectiveStatus(
                        dueDate: occurrence,
                        now: now,
                        calendar: calendar
                    )
                if status == .pending || status == .overdue {
                    result.receivableIncome += income.amount
                }
            }
        }

        for expense in fixedExpenses where expense.isActive {
            for _ in fixedExpenseOccurrences(for: expense, interval: interval) {
                result.totalExpenses += expense.amount
                result.entryCount += 1
            }
        }

        return result
    }

    private func daysUntilNextIncome(
        incomes: [Income],
        now: Date
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let nextDate = incomes
            .filter(\.isActive)
            .compactMap { nextIncomeDate(for: $0, onOrAfter: today) }
            .min()
        guard let nextDate else {
            return 0
        }
        return max(
            calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0,
            0
        )
    }

    private func nextIncomeDate(for income: Income, onOrAfter date: Date) -> Date? {
        var occurrence = calendar.startOfDay(for: income.dueDate ?? income.date)
        if income.recurrence == .oneTime {
            return occurrence >= date ? occurrence : nil
        }
        while occurrence < date {
            guard let next = nextIncomeOccurrence(
                after: occurrence,
                recurrence: income.recurrence
            ), next > occurrence else { return nil }
            occurrence = next
        }
        return occurrence
    }

    private func incomeOccurrences(
        for income: Income,
        interval: DateInterval
    ) -> [Date] {
        var occurrence = calendar.startOfDay(for: income.dueDate ?? income.date)

        if income.recurrence == .oneTime {
            return interval.contains(occurrence) ? [occurrence] : []
        }

        while occurrence < interval.start {
            guard let next = nextIncomeOccurrence(
                after: occurrence,
                recurrence: income.recurrence
            ), next > occurrence else {
                return []
            }
            occurrence = next
        }

        var result: [Date] = []
        while occurrence < interval.end {
            result.append(occurrence)
            guard let next = nextIncomeOccurrence(
                after: occurrence,
                recurrence: income.recurrence
            ), next > occurrence else {
                break
            }
            occurrence = next
        }
        return result
    }

    private func fixedExpenseOccurrences(
        for expense: FixedExpense,
        interval: DateInterval
    ) -> [Date] {
        let firstOccurrence = expense.dueDate
            ?? firstMonthlyDate(day: expense.dueDay, onOrAfter: interval.start)
        guard var occurrence = firstOccurrence.map({
            calendar.startOfDay(for: $0)
        }) else {
            return []
        }

        while occurrence < interval.start {
            guard let next = nextExpenseOccurrence(
                after: occurrence,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths
            ), next > occurrence else {
                return []
            }
            occurrence = next
        }

        var result: [Date] = []
        while occurrence < interval.end {
            result.append(occurrence)
            guard let next = nextExpenseOccurrence(
                after: occurrence,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths
            ), next > occurrence else {
                break
            }
            occurrence = next
        }
        return result
    }

    private func firstMonthlyDate(day: Int, onOrAfter date: Date) -> Date? {
        let start = calendar.startOfDay(for: date)
        var components = calendar.dateComponents([.year, .month], from: start)
        components.day = min(max(day, 1), 28)
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate >= start
            ? candidate
            : calendar.date(byAdding: .month, value: 1, to: candidate)
    }

    private func nextIncomeOccurrence(
        after date: Date,
        recurrence: IncomeRecurrence
    ) -> Date? {
        switch recurrence {
        case .oneTime: nil
        case .weekly: calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    private func nextExpenseOccurrence(
        after date: Date,
        recurrence: ExpenseRecurrence,
        customMonths: Int
    ) -> Date? {
        switch recurrence {
        case .weekly: calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual: calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        case .custom:
            calendar.date(
                byAdding: .month,
                value: max(customMonths, 1),
                to: date
            )
        }
    }
}

private struct DashboardMetricView: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())

            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
            Income.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
