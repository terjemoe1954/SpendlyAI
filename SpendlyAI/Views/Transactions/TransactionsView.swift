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

    private var currencyCode: String {
        profiles.first?.currencyCode ?? Locale.current.currency?.identifier ?? "NOK"
    }

    private var activityItems: [ActivityItem] {
        switch activityFilter {
        case .all:
            return mergeActivities(
                transactions: transactions,
                incomes: incomes,
                fixedExpenses: fixedExpenses
            )
        case .purchases:
            return transactions.map(ActivityItem.purchase)
        case .incomes:
            return incomes.map(ActivityItem.income)
        case .fixedExpenses:
            return preparedFixedExpenseItems(fixedExpenses)
        }
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
                        onDelete: delete
                    )
                }
            }
            .navigationTitle("tab.transactions")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink {
                        IncomesView()
                    } label: {
                        Image(systemName: "banknote")
                    }
                    .accessibilityLabel("incomes.title")

                    Menu {
                        Picker("transactions.filter", selection: $activityFilter) {
                            ForEach(ActivityFilter.allCases) { filter in
                                Text(filter.titleKey).tag(filter)
                            }
                        }
                    } label: {
                        Label("transactions.filter", systemImage: "line.3.horizontal.decrease.circle")
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
            guard let dueDate = nextDueDate(forDay: expense.dueDay) else {
                return nil
            }
            return .fixedExpense(expense, dueDate: dueDate)
        }
        .sorted { $0.date > $1.date }
    }

    private func nextDueDate(forDay day: Int, from date: Date = .now) -> Date? {
        let calendar = Calendar.current
        let safeDay = min(max(day, 1), 28)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = safeDay

        guard let dueDateThisMonth = calendar.date(from: components) else {
            return nil
        }

        if dueDateThisMonth >= calendar.startOfDay(for: date) {
            return dueDateThisMonth
        }

        return calendar.date(byAdding: .month, value: 1, to: dueDateThisMonth)
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

    var date: Date {
        switch self {
        case .purchase(let transaction): transaction.date
        case .income(let income): income.date
        case .fixedExpense(_, let dueDate): dueDate
        }
    }
}

private struct ActivityList: View {
    let items: [ActivityItem]
    let currencyCode: String
    let onSelect: (ActivityItem) -> Void
    let onDelete: (ActivityItem) -> Void

    var body: some View {
        List(items) { item in
            Button {
                onSelect(item)
            } label: {
                ActivityRow(item: item, currencyCode: currencyCode)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button("common.delete", role: .destructive) {
                    onDelete(item)
                }
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
                date: transaction.date,
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
                date: income.date,
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
