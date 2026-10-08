import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var profiles: [UserFinancialProfile]

    @State private var period: StatisticsPeriod = .thisMonth
    @State private var customStartDate = Calendar.current.date(
        byAdding: .month,
        value: -1,
        to: .now
    ) ?? .now
    @State private var customEndDate = Date.now

    private var currencyCode: String {
        profiles.first?.currencyCode ?? "NOK"
    }

    private var interval: DateInterval {
        period.interval(
            customStartDate: customStartDate,
            customEndDate: customEndDate
        )
    }

    private var entries: [StatisticsEntry] {
        StatisticsCalculator().entries(
            transactions: transactions,
            incomes: incomes,
            fixedExpenses: fixedExpenses,
            profile: profiles.first,
            interval: interval
        )
    }

    private var categoryBalances: [CategoryBalance] {
        StatisticsCategory.allCases.compactMap { category in
            let categoryEntries = entries.filter { $0.category == category }
            guard !categoryEntries.isEmpty else { return nil }
            return CategoryBalance(
                category: category,
                amount: categoryEntries.reduce(.zero) { $0 + $1.signedAmount },
                entries: categoryEntries.sorted { $0.date > $1.date }
            )
        }
        .sorted { absDecimal($0.amount) > absDecimal($1.amount) }
    }

    private var totalIncome: Decimal {
        entries.filter { $0.kind == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var totalExpenses: Decimal {
        entries.filter { $0.kind == .expense }.reduce(.zero) { $0 + $1.amount }
    }

    private var netResult: Decimal {
        totalIncome - totalExpenses
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                periodSection
                summarySection

                if categoryBalances.isEmpty {
                    ContentUnavailableView(
                        "statistics.empty.title",
                        systemImage: "chart.bar",
                        description: Text("statistics.empty.message")
                    )
                } else {
                    chartSection
                    categorySection
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppStyle.screenBackground)
        .navigationTitle("statistics.title")
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Picker("filter.period", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { option in
                    Text(option.titleKey).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if period == .custom {
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
                Text(interval.start, format: .dateTime.day().month(.wide).year())
                Text(verbatim: "–")
                Text(
                    interval.end.addingTimeInterval(-1),
                    format: .dateTime.day().month(.wide).year()
                )
            }
        }
        .padding(AppSpacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summarySection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppSpacing.medium
        ) {
            StatisticsMetric(
                titleKey: "statistics.income",
                amount: totalIncome,
                currencyCode: currencyCode,
                color: AppStyle.accentColor
            )
            StatisticsMetric(
                titleKey: "statistics.expenses",
                amount: totalExpenses,
                currencyCode: currencyCode,
                color: .red
            )
            StatisticsMetric(
                titleKey: "statistics.net",
                amount: netResult,
                currencyCode: currencyCode,
                color: netResult < 0 ? .red : AppStyle.accentColor
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("statistics.categoryBalance")
                .font(.headline)

            Chart(categoryBalances) { balance in
                BarMark(
                    x: .value("statistics.net", decimalDouble(balance.amount)),
                    y: .value("filter.category", balance.category.localizedTitle)
                )
                .foregroundStyle(balance.amount < 0 ? Color.red : AppStyle.accentColor)
                .accessibilityLabel(Text(balance.category.titleKey))
                .accessibilityValue(
                    Text(MoneyFormatter.string(from: balance.amount, currencyCode: currencyCode))
                )
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(minHeight: max(220, CGFloat(categoryBalances.count) * 34))
        }
        .padding(AppSpacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(categoryBalances) { balance in
                NavigationLink {
                    StatisticsCategoryDetailView(
                        balance: balance,
                        currencyCode: currencyCode
                    )
                } label: {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: balance.category.systemImage)
                            .foregroundStyle(balance.amount < 0 ? .red : AppStyle.accentColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(balance.category.titleKey)
                                .foregroundStyle(.primary)
                            HStack(spacing: 3) {
                                Text(balance.entries.count.formatted())
                                Text("statistics.entries")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(MoneyFormatter.string(
                            from: balance.amount,
                            currencyCode: currencyCode
                        ))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(balance.amount < 0 ? .red : AppStyle.accentColor)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(AppSpacing.medium)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func absDecimal(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct StatisticsMetric: View {
    let titleKey: LocalizedStringKey
    let amount: Decimal
    let currencyCode: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoneyFormatter.string(from: amount, currencyCode: currencyCode))
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatisticsCategoryDetailView: View {
    let balance: CategoryBalance
    let currencyCode: String

    var body: some View {
        List(balance.entries) { entry in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: entry.title)
                        .font(.body.weight(.medium))
                    Text(entry.date, format: .dateTime.day().month(.wide).year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(MoneyFormatter.string(
                    from: entry.signedAmount,
                    currencyCode: currencyCode
                ))
                .foregroundStyle(entry.kind == .income ? AppStyle.accentColor : .red)
            }
        }
        .navigationTitle(balance.category.titleKey)
    }
}

private enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case thisMonth
    case previousMonth
    case thisYear
    case custom

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .thisMonth: "filter.period.thisMonth"
        case .previousMonth: "filter.period.previousMonth"
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
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
                ?? DateInterval(start: now, duration: 1)
        case .previousMonth:
            let previous = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: previous)
                ?? DateInterval(start: previous, duration: 1)
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

private enum StatisticsEntryKind {
    case income
    case expense
}

private struct StatisticsEntry: Identifiable {
    let id: String
    let title: String
    let date: Date
    let amount: Decimal
    let category: StatisticsCategory
    let kind: StatisticsEntryKind

    var signedAmount: Decimal {
        kind == .income ? amount : -amount
    }
}

private struct CategoryBalance: Identifiable {
    var id: StatisticsCategory { category }
    let category: StatisticsCategory
    let amount: Decimal
    let entries: [StatisticsEntry]
}

private enum StatisticsCategory: String, CaseIterable, Identifiable {
    case subscriptions
    case other
    case groceries
    case insurance
    case gifts
    case health
    case home
    case income
    case clothing
    case communication
    case gambling
    case savings
    case transport
    case withdrawals
    case entertainment
    case developer

    var id: Self { self }

    var titleKeyString: String {
        switch self {
        case .subscriptions: "expenseCategory.subscriptions"
        case .other: "category.other"
        case .groceries: "category.groceries"
        case .insurance: "expenseCategory.insurance"
        case .gifts: "category.gifts"
        case .health: "category.health"
        case .home: "category.home"
        case .income: "category.income"
        case .clothing: "category.clothing"
        case .communication: "category.communication"
        case .gambling: "category.gambling"
        case .savings: "category.savings"
        case .transport: "category.transport"
        case .withdrawals: "category.withdrawals"
        case .entertainment: "category.entertainment"
        case .developer: "category.developer"
        }
    }

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(titleKeyString)
    }

    var localizedTitle: String {
        String(localized: String.LocalizationValue(titleKeyString))
    }

    var systemImage: String {
        switch self {
        case .subscriptions: "repeat"
        case .other: "tag"
        case .groceries: "basket"
        case .insurance: "shield"
        case .gifts: "gift"
        case .health: "cross.case"
        case .home: "house"
        case .income: "arrow.down.circle"
        case .clothing: "tshirt"
        case .communication: "phone"
        case .gambling: "dice"
        case .savings: "banknote"
        case .transport: "car"
        case .withdrawals: "minus.circle"
        case .entertainment: "ticket"
        case .developer: "hammer"
        }
    }

    init(spendingCategory: SpendingCategory) {
        switch spendingCategory {
        case .home, .bills: self = .home
        case .food, .groceries: self = .groceries
        case .shopping, .other: self = .other
        default: self = Self(rawValue: spendingCategory.rawValue) ?? .other
        }
    }

    init(incomeCategory: IncomeCategory) {
        self = Self(rawValue: incomeCategory.normalizedCategory.rawValue) ?? .income
    }

    init(expenseCategory: ExpenseCategory) {
        switch expenseCategory {
        case .housing, .utilities: self = .home
        case .debt, .childcare, .other: self = .other
        default: self = Self(rawValue: expenseCategory.rawValue) ?? .other
        }
    }
}

private struct StatisticsCalculator {
    private let calendar = Calendar.current

    func entries(
        transactions: [Transaction],
        incomes: [Income],
        fixedExpenses: [FixedExpense],
        profile: UserFinancialProfile?,
        interval: DateInterval
    ) -> [StatisticsEntry] {
        let purchases = transactions.compactMap { transaction -> StatisticsEntry? in
            let date = transaction.dueDate ?? transaction.date
            guard interval.contains(date) else { return nil }
            return StatisticsEntry(
                id: "purchase-\(transaction.persistentModelID)",
                title: transaction.transactionDescription.isEmpty
                    ? String(localized: "transaction.untitled")
                    : transaction.transactionDescription,
                date: date,
                amount: transaction.amount,
                category: StatisticsCategory(spendingCategory: transaction.category),
                kind: .expense
            )
        }

        let registeredIncomes = incomes.compactMap { income -> StatisticsEntry? in
            let date = income.dueDate ?? income.date
            guard interval.contains(date) else { return nil }
            return StatisticsEntry(
                id: "income-\(income.persistentModelID)",
                title: income.incomeDescription.isEmpty
                    ? String(localized: "income.untitled")
                    : income.incomeDescription,
                date: date,
                amount: income.amount,
                category: StatisticsCategory(incomeCategory: income.category),
                kind: .income
            )
        }

        let recurringExpenses = fixedExpenses.flatMap {
            fixedExpenseEntries(for: $0, interval: interval)
        }
        let profileIncomes = profile.map {
            profileIncomeEntries(
                for: $0,
                registeredIncomes: incomes,
                interval: interval
            )
        } ?? []

        return purchases + registeredIncomes + recurringExpenses + profileIncomes
    }

    private func fixedExpenseEntries(
        for expense: FixedExpense,
        interval: DateInterval
    ) -> [StatisticsEntry] {
        guard expense.isActive else { return [] }

        let firstOccurrence = expense.dueDate
            ?? firstMonthlyDate(day: expense.dueDay, onOrAfter: interval.start)
        guard var occurrence = firstOccurrence else { return [] }

        while occurrence < interval.start {
            guard let next = nextOccurrence(after: occurrence, expense: expense),
                  next > occurrence else { return [] }
            occurrence = next
        }

        var result: [StatisticsEntry] = []
        while occurrence < interval.end {
            result.append(StatisticsEntry(
                id: "fixed-\(expense.persistentModelID)-\(occurrence.timeIntervalSince1970)",
                title: expense.name,
                date: occurrence,
                amount: expense.amount,
                category: StatisticsCategory(expenseCategory: expense.category),
                kind: .expense
            ))
            guard let next = nextOccurrence(after: occurrence, expense: expense),
                  next > occurrence else { break }
            occurrence = next
        }
        return result
    }

    private func profileIncomeEntries(
        for profile: UserFinancialProfile,
        registeredIncomes: [Income],
        interval: DateInterval
    ) -> [StatisticsEntry] {
        guard profile.monthlyNetIncome > 0,
              var occurrence = firstMonthlyDate(
                day: profile.paydayDay,
                onOrAfter: interval.start
              ) else { return [] }

        var result: [StatisticsEntry] = []
        while occurrence < interval.end {
            let alreadyRegistered = registeredIncomes.contains { income in
                income.category == .salary
                    && calendar.isDate(income.dueDate ?? income.date, inSameDayAs: occurrence)
            }
            if !alreadyRegistered {
                result.append(StatisticsEntry(
                    id: "profile-income-\(occurrence.timeIntervalSince1970)",
                    title: String(localized: "report.profileIncome"),
                    date: occurrence,
                    amount: profile.monthlyNetIncome,
                    category: .income,
                    kind: .income
                ))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: occurrence) else {
                break
            }
            occurrence = next
        }
        return result
    }

    private func firstMonthlyDate(day: Int, onOrAfter date: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(max(day, 1), 28)
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate >= date
            ? candidate
            : calendar.date(byAdding: .month, value: 1, to: candidate)
    }

    private func nextOccurrence(after date: Date, expense: FixedExpense) -> Date? {
        switch expense.recurrence {
        case .weekly:
            calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual:
            calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date)
        case .custom:
            calendar.date(
                byAdding: .month,
                value: max(expense.customRecurrenceMonths, 1),
                to: date
            )
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [
        UserFinancialProfile.self,
        FixedExpense.self,
        Transaction.self,
        Income.self,
        SavingsGoal.self,
        DailyBudgetSnapshot.self
    ], inMemory: true)
}
