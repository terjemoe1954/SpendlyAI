//
//  TransactionsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var profiles: [UserFinancialProfile]

    @State private var showsNewTransaction = false
    @State private var showsNewIncome = false
    @State private var selectedTransaction: Transaction?
    @State private var selectedIncome: Income?
    @State private var selectedFixedExpense: FixedExpense?
    @State private var activityFilter: ActivityFilter = .all
    @State private var showsFilters = false
    @State private var periodFilter: ActivityPeriodFilter = .all
    @State private var statusFilter: PaymentStatus?
    @State private var categoryFilter: ActivityCategory?
    @State private var minimumAmount = ""
    @State private var maximumAmount = ""

    private var currencyCode: String {
        profiles.first?.currencyCode ?? Locale.current.currency?.identifier ?? "NOK"
    }

    private var activityItems: [ActivityItem] {
        let items: [ActivityItem]
        switch activityFilter {
        case .all:
            items = mergeActivities(
                transactions: transactions,
                incomes: incomes,
                fixedExpenses: fixedExpenses
            )
        case .purchases:
            items = transactions.map(ActivityItem.purchase)
                .sorted { $0.date > $1.date }
        case .incomes:
            items = incomes.map(ActivityItem.income)
                .sorted { $0.date > $1.date }
        case .fixedExpenses:
            items = preparedFixedExpenseItems(fixedExpenses)
        }

        let minimum = MoneyParser.decimal(from: minimumAmount)
        let maximum = MoneyParser.decimal(from: maximumAmount)
        return items.filter { item in
            periodFilter.contains(item.date)
                && (statusFilter == nil || item.paymentStatus == statusFilter)
                && (categoryFilter == nil || item.category == categoryFilter)
                && minimum.map { item.amount >= $0 } != false
                && maximum.map { item.amount <= $0 } != false
        }
    }

    private var hasActiveFilters: Bool {
        periodFilter != .all || statusFilter != nil || categoryFilter != nil
            || MoneyParser.decimal(from: minimumAmount) != nil
            || MoneyParser.decimal(from: maximumAmount) != nil
            || activityFilter != .all
    }

    var body: some View {
        NavigationStack {
            Group {
                if activityItems.isEmpty {
                    ContentUnavailableView(
                        "transactions.empty.title",
                        systemImage: "list.bullet.rectangle",
                        description: Text("transactions.empty.message")
                    )
                } else {
                    ActivityList(
                        items: activityItems,
                        currencyCode: currencyCode,
                        onSelect: select,
                        onCopy: copy,
                        onDelete: delete
                    )
                }
            }
            .navigationTitle("tab.transactions")
            .toolbar {
                ToolbarOverflowMenu {
                    NavigationLink {
                        IncomesView()
                    } label: {
                        Label("incomes.title", systemImage: "banknote")
                    }

                    NavigationLink {
                        StatisticsView()
                    } label: {
                        Label("statistics.title", systemImage: "chart.bar.xaxis")
                    }

                    Button {
                        showsFilters = true
                    } label: {
                        Label(
                            "transactions.filter",
                            systemImage: hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("transaction.new.title", systemImage: "cart.badge.plus") {
                            showsNewTransaction = true
                        }
                        Button("income.add", systemImage: "banknote") {
                            showsNewIncome = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("common.add")
                }
            }
            .sheet(isPresented: $showsFilters) {
                TransactionFilterView(
                    activityFilter: $activityFilter,
                    periodFilter: $periodFilter,
                    statusFilter: $statusFilter,
                    categoryFilter: $categoryFilter,
                    minimumAmount: $minimumAmount,
                    maximumAmount: $maximumAmount
                )
            }
            .sheet(isPresented: $showsNewTransaction) {
                TransactionEditorView()
            }
            .sheet(isPresented: $showsNewIncome) {
                IncomeEditorView(income: nil)
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction)
            }
            .sheet(item: $selectedIncome) { income in
                IncomeEditorView(income: income)
            }
            .sheet(item: $selectedFixedExpense) { expense in
                FixedExpenseEditorView(expense: expense)
            }
        }
    }

    private func select(_ item: ActivityItem) {
        switch item {
        case .purchase(let transaction):
            selectedTransaction = transaction
        case .income(let income):
            selectedIncome = income
        case .fixedExpense(let expense, _):
            selectedFixedExpense = expense
        }
    }

    private func copy(_ item: ActivityItem) {
        switch item {
        case .purchase(let transaction):
            let copy = Transaction(
                amount: transaction.amount,
                date: transaction.date,
                category: transaction.category,
                transactionDescription: transaction.transactionDescription,
                isEssential: transaction.isEssential,
                notes: transaction.notes,
                dueDate: transaction.dueDate,
                settledDate: transaction.settledDate,
                paymentStatus: transaction.paymentStatus
            )
            modelContext.insert(copy)
            try? modelContext.save()
            selectedTransaction = copy
        case .income(let income):
            let copy = Income(
                amount: income.amount,
                date: income.date,
                category: income.category,
                incomeDescription: income.incomeDescription,
                notes: income.notes,
                recurrence: income.recurrence,
                isActive: income.isActive,
                dueDate: income.dueDate,
                settledDate: income.settledDate,
                paymentStatus: income.paymentStatus
            )
            modelContext.insert(copy)
            try? modelContext.save()
            selectedIncome = copy
        case .fixedExpense(let expense, _):
            let copy = FixedExpense(
                name: expense.name,
                amount: expense.amount,
                dueDay: expense.dueDay,
                category: expense.category,
                recurrence: expense.recurrence,
                customRecurrenceMonths: expense.customRecurrenceMonths,
                isActive: expense.isActive,
                dueDate: expense.dueDate,
                settledDate: expense.settledDate,
                paymentStatus: expense.paymentStatus
            )
            modelContext.insert(copy)
            try? modelContext.save()
            selectedFixedExpense = copy
        }
    }

    private func delete(_ item: ActivityItem) {
        switch item {
        case .purchase(let transaction):
            modelContext.delete(transaction)
        case .income(let income):
            modelContext.delete(income)
        case .fixedExpense(let expense, _):
            modelContext.delete(expense)
        }
        try? modelContext.save()
    }

    private func mergeActivities(
        transactions: [Transaction],
        incomes: [Income],
        fixedExpenses: [FixedExpense]
    ) -> [ActivityItem] {
        let recordedItems = transactions.map(ActivityItem.purchase)
            + incomes.map(ActivityItem.income)
        let fixedExpenseItems = preparedFixedExpenseItems(fixedExpenses)

        return (recordedItems + fixedExpenseItems)
            .sorted { $0.date > $1.date }
    }

    private func preparedFixedExpenseItems(_ expenses: [FixedExpense]) -> [ActivityItem] {
        expenses.compactMap { expense in
            guard let dueDate = nextDueDate(for: expense) else {
                return nil
            }
            return .fixedExpense(expense, dueDate: dueDate)
        }
        .sorted { $0.date > $1.date }
    }

    private func nextDueDate(for expense: FixedExpense, from date: Date = .now) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        guard var dueDate = expense.dueDate else {
            return nextMonthlyDueDate(forDay: expense.dueDay, from: today)
        }

        dueDate = calendar.startOfDay(for: dueDate)
        while dueDate < today {
            guard let nextDate = nextOccurrence(
                after: dueDate,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths
            ), nextDate > dueDate else {
                return nil
            }
            dueDate = nextDate
        }

        return dueDate
    }

    private func nextMonthlyDueDate(forDay day: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let safeDay = min(max(day, 1), 28)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = safeDay

        guard let dueDateThisMonth = calendar.date(from: components) else {
            return nil
        }

        if dueDateThisMonth >= date {
            return dueDateThisMonth
        }

        return calendar.date(byAdding: .month, value: 1, to: dueDateThisMonth)
    }

    private func nextOccurrence(
        after date: Date,
        recurrence: ExpenseRecurrence,
        customMonths: Int
    ) -> Date? {
        let calendar = Calendar.current

        return switch recurrence {
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
            calendar.date(byAdding: .month, value: max(customMonths, 1), to: date)
        }
    }
}

private struct TransactionFilterView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var activityFilter: ActivityFilter
    @Binding var periodFilter: ActivityPeriodFilter
    @Binding var statusFilter: PaymentStatus?
    @Binding var categoryFilter: ActivityCategory?
    @Binding var minimumAmount: String
    @Binding var maximumAmount: String

    var body: some View {
        NavigationStack {
            Form {
                Section("filter.period") {
                    Picker("filter.period", selection: $periodFilter) {
                        ForEach(ActivityPeriodFilter.allCases) { period in
                            Text(period.titleKey).tag(period)
                        }
                    }
                }

                Section("filter.status") {
                    Picker("filter.status", selection: $statusFilter) {
                        Text("filter.all").tag(nil as PaymentStatus?)
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.titleKey(for: .expense)).tag(status as PaymentStatus?)
                        }
                    }
                }

                Section("filter.type") {
                    Picker("filter.type", selection: $activityFilter) {
                        ForEach(ActivityFilter.allCases) { filter in
                            Text(filter.titleKey).tag(filter)
                        }
                    }
                }

                Section("filter.category") {
                    Picker("filter.category", selection: $categoryFilter) {
                        Text("filter.allCategories").tag(nil as ActivityCategory?)
                        ForEach(ActivityCategory.allCases) { category in
                            Text(category.titleKey).tag(category as ActivityCategory?)
                        }
                    }
                }

                Section("filter.amount") {
                    TextField("filter.minimumAmount", text: $minimumAmount)
                    TextField("filter.maximumAmount", text: $maximumAmount)
                }

                Section {
                    Button("filter.reset", role: .destructive) {
                        activityFilter = .all
                        periodFilter = .all
                        statusFilter = nil
                        categoryFilter = nil
                        minimumAmount = ""
                        maximumAmount = ""
                    }
                }
            }
            .navigationTitle("transactions.filter")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum ActivityPeriodFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case thisMonth
    case previousMonth
    case thisYear

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "filter.period.all"
        case .today: "filter.period.today"
        case .thisMonth: "filter.period.thisMonth"
        case .previousMonth: "filter.period.previousMonth"
        case .thisYear: "filter.period.thisYear"
        }
    }

    func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            true
        case .today:
            calendar.isDate(date, inSameDayAs: now)
        case .thisMonth:
            calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .previousMonth:
            calendar.date(byAdding: .month, value: -1, to: now)
                .map { calendar.isDate(date, equalTo: $0, toGranularity: .month) } ?? false
        case .thisYear:
            calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }
}

private enum ActivityCategory: String, CaseIterable, Identifiable {
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

    var titleKey: LocalizedStringKey {
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
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case purchases
    case incomes
    case fixedExpenses

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "activity.filter.all"
        case .purchases: "activity.filter.purchases"
        case .incomes: "activity.filter.incomes"
        case .fixedExpenses: "fixedExpenses.title"
        }
    }
}

private enum ActivityItem: Identifiable {
    enum ID: Hashable {
        case purchase(PersistentIdentifier)
        case income(PersistentIdentifier)
        case fixedExpense(PersistentIdentifier)
    }

    case purchase(Transaction)
    case income(Income)
    case fixedExpense(FixedExpense, dueDate: Date)

    var id: ID {
        switch self {
        case .purchase(let transaction): .purchase(transaction.persistentModelID)
        case .income(let income): .income(income.persistentModelID)
        case .fixedExpense(let expense, _): .fixedExpense(expense.persistentModelID)
        }
    }

    var editTitleKey: LocalizedStringKey {
        switch self {
        case .purchase: "transaction.edit.title"
        case .income: "income.edit"
        case .fixedExpense: "fixedExpenses.edit"
        }
    }

    var date: Date {
        switch self {
        case .purchase(let transaction): transaction.dueDate ?? transaction.date
        case .income(let income): income.dueDate ?? income.date
        case .fixedExpense(_, let dueDate): dueDate
        }
    }

    var amount: Decimal {
        switch self {
        case .purchase(let transaction): transaction.amount
        case .income(let income): income.amount
        case .fixedExpense(let expense, _): expense.amount
        }
    }

    var paymentStatus: PaymentStatus {
        switch self {
        case .purchase(let transaction): transaction.effectivePaymentStatus()
        case .income(let income): income.effectivePaymentStatus()
        case .fixedExpense(let expense, let dueDate):
            expense.paymentStatus.effectiveStatus(dueDate: dueDate)
        }
    }

    var category: ActivityCategory {
        switch self {
        case .purchase(let transaction):
            switch transaction.category {
            case .home, .bills: .home
            case .food, .groceries: .groceries
            case .shopping, .other: .other
            default: ActivityCategory(rawValue: transaction.category.rawValue) ?? .other
            }
        case .income(let income):
            ActivityCategory(rawValue: income.category.normalizedCategory.rawValue) ?? .income
        case .fixedExpense(let expense, _):
            switch expense.category {
            case .housing, .utilities: .home
            case .debt, .childcare, .other: .other
            default: ActivityCategory(rawValue: expense.category.rawValue) ?? .other
            }
        }
    }
}

private struct ActivityList: View {
    let items: [ActivityItem]
    let currencyCode: String
    let onSelect: (ActivityItem) -> Void
    let onCopy: (ActivityItem) -> Void
    let onDelete: (ActivityItem) -> Void

    var body: some View {
        List(items) { item in
            Button {
                onSelect(item)
            } label: {
                ActivityRow(item: item, currencyCode: currencyCode)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    onSelect(item)
                } label: {
                    Label(item.editTitleKey, systemImage: "pencil")
                }
                .tint(.blue)

                Button {
                    onCopy(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onDelete(item)
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ActivityRow: View {
    let item: ActivityItem
    let currencyCode: String

    var body: some View {
        switch item {
        case .purchase(let transaction):
            ActivityRowContent(
                systemImage: transaction.category.systemImage,
                title: transaction.transactionDescription,
                untitledKey: "transaction.untitled",
                categoryKey: transaction.category.titleKey,
                date: transaction.dueDate ?? transaction.date,
                amount: transaction.amount,
                currencyCode: currencyCode,
                isIncome: false,
                paymentStatus: transaction.effectivePaymentStatus()
            )
        case .income(let income):
            ActivityRowContent(
                systemImage: income.category.systemImage,
                title: income.incomeDescription,
                untitledKey: "income.untitled",
                categoryKey: income.category.titleKey,
                date: income.dueDate ?? income.date,
                amount: income.amount,
                currencyCode: currencyCode,
                isIncome: true,
                paymentStatus: income.effectivePaymentStatus()
            )
        case .fixedExpense(let expense, let dueDate):
            FixedExpenseActivityRowContent(
                expense: expense,
                dueDate: dueDate,
                currencyCode: currencyCode
            )
        }
    }
}

private struct FixedExpenseActivityRowContent: View {
    @Environment(\.locale) private var locale

    let expense: FixedExpense
    let dueDate: Date
    let currencyCode: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: expense.category.systemImage)
                .font(.headline)
                .foregroundStyle(expense.isActive ? Color.orange : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    (expense.isActive ? Color.orange : Color.secondary).opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: expense.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 6) {
                    Text(expense.category.activityTitleKey)
                    Text(expense.recurrence.activityTitleKey)
                    Text(dueDate, format: .dateTime.day().month())
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(expense.paymentStatus.effectiveStatus(dueDate: dueDate).titleKey(for: .expense))
                    .font(.caption)
                    .foregroundStyle(expense.paymentStatus.effectiveStatus(dueDate: dueDate).displayColor)
            }

            Spacer()

            Text(MoneyFormatter.string(
                from: expense.amount,
                currencyCode: currencyCode,
                locale: locale
            ))
                .font(.body.weight(.semibold))
                .foregroundStyle(expense.isActive ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 4)
        .opacity(expense.isActive ? 1 : 0.7)
    }
}

private struct ActivityRowContent: View {
    @Environment(\.locale) private var locale

    let systemImage: String
    let title: String
    let untitledKey: LocalizedStringKey
    let categoryKey: LocalizedStringKey
    let date: Date
    let amount: Decimal
    let currencyCode: String
    let isIncome: Bool
    let paymentStatus: PaymentStatus

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(isIncome ? AppStyle.accentColor : .primary)
                .frame(width: 32, height: 32)
                .background(
                    (isIncome ? AppStyle.accentColor : Color.secondary).opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if title.isEmpty {
                    Text(untitledKey)
                        .font(.body.weight(.medium))
                } else {
                    Text(verbatim: title)
                        .font(.body.weight(.medium))
                }

                HStack(spacing: 6) {
                    Text(categoryKey)
                    Text(date, format: .dateTime.day().month().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(paymentStatus.titleKey(for: isIncome ? .income : .expense))
                    .font(.caption)
                    .foregroundStyle(paymentStatus.displayColor)
            }

            Spacer()

            Text(MoneyFormatter.string(
                from: amount,
                currencyCode: currencyCode,
                locale: locale
            ))
                .font(.body.weight(.semibold))
                .foregroundStyle(isIncome ? AppStyle.accentColor : .primary)
        }
        .padding(.vertical, 4)
    }
}

private extension SpendingCategory {
    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .groceries: "basket"
        case .transport: "car"
        case .shopping: "bag"
        case .entertainment: "ticket"
        case .gambling: "dice"
        case .health: "cross.case"
        case .bills: "doc.text"
        case .savings: "banknote"
        case .subscriptions: "repeat"
        case .insurance: "shield"
        case .gifts: "gift"
        case .home: "house"
        case .income: "arrow.down.circle"
        case .clothing: "tshirt"
        case .communication: "phone"
        case .withdrawals: "banknote"
        case .developer: "hammer"
        case .other: "circle.grid.2x2"
        }
    }
}

private extension ExpenseCategory {
    var activityTitleKey: LocalizedStringKey {
        switch self {
        case .gifts: "category.gifts"
        case .income: "category.income"
        case .clothing: "category.clothing"
        case .communication: "category.communication"
        case .savings: "category.savings"
        case .withdrawals: "category.withdrawals"
        case .entertainment: "category.entertainment"
        case .developer: "category.developer"
        case .housing: "expenseCategory.housing"
        case .utilities: "expenseCategory.utilities"
        case .insurance: "expenseCategory.insurance"
        case .transport: "expenseCategory.transport"
        case .subscriptions: "expenseCategory.subscriptions"
        case .debt: "expenseCategory.debt"
        case .childcare: "expenseCategory.childcare"
        case .groceries: "expenseCategory.groceries"
        case .health: "expenseCategory.health"
        case .gambling: "expenseCategory.gambling"
        case .other: "expenseCategory.other"
        }
    }

    var systemImage: String {
        switch self {
        case .housing: "house"
        case .utilities: "bolt"
        case .insurance: "shield"
        case .transport: "car"
        case .subscriptions: "repeat"
        case .debt: "creditcard"
        case .childcare: "figure.2.and.child.holdinghands"
        case .groceries: "basket"
        case .health: "cross.case"
        case .gambling: "dice"
        case .gifts: "gift"
        case .income: "arrow.down.circle"
        case .clothing: "tshirt"
        case .communication: "phone"
        case .savings: "banknote"
        case .withdrawals: "banknote"
        case .entertainment: "ticket"
        case .developer: "hammer"
        case .other: "doc.text"
        }
    }
}

private extension ExpenseRecurrence {
    var activityTitleKey: LocalizedStringKey {
        switch self {
        case .weekly: "expenseRecurrence.weekly"
        case .biweekly: "expenseRecurrence.biweekly"
        case .monthly: "expenseRecurrence.monthly"
        case .quarterly: "expenseRecurrence.quarterly"
        case .semiannual: "expenseRecurrence.semiannual"
        case .yearly: "expenseRecurrence.yearly"
        case .custom: "expenseRecurrence.custom"
        }
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            Income.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
