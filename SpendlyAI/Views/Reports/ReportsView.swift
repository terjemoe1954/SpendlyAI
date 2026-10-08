import SwiftData
import SwiftUI

private enum ReportStatusFilter: String, CaseIterable, Identifiable {
    case all
    case paid
    case pending
    case overdue

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .all: "report.status.all"
        case .paid: "report.status.paid"
        case .pending: "paymentStatus.pending"
        case .overdue: "paymentStatus.overdue"
        }
    }

    var title: LocalizedStringKey { LocalizedStringKey(localizationKey) }
}

private enum ReportSortOption: String, CaseIterable, Identifiable {
    case dateAscending
    case dateDescending
    case amountDescending

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .dateAscending: "report.sort.dateAscending"
        case .dateDescending: "report.sort.dateDescending"
        case .amountDescending: "report.sort.amountDescending"
        }
    }

    var title: LocalizedStringKey { LocalizedStringKey(localizationKey) }
}

struct ReportsView: View {
    @Environment(\.locale) private var locale

    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]
    @Query private var profiles: [UserFinancialProfile]

    @State private var startDate = Calendar.current.date(
        byAdding: .month,
        value: -1,
        to: .now
    ) ?? .now
    @State private var endDate = Date.now
    @State private var statusFilter: ReportStatusFilter = .all
    @State private var sortOption: ReportSortOption = .dateAscending
    @State private var pdfPreview: ReportPDFPreview?

    private var currencyCode: String {
        profiles.first?.currencyCode ?? "NOK"
    }

    private var summary: ReportSummary {
        ReportSummaryService().makeSummary(
            transactions: transactions,
            incomes: incomes,
            fixedExpenses: fixedExpenses,
            savingsGoals: savingsGoals,
            profile: profiles.first,
            startDate: startDate,
            endDate: endDate
        )
    }

    private var csvEntries: [ReportCSVEntry] {
        let calendar = Calendar.current
        let lowerBound = calendar.startOfDay(for: min(startDate, endDate))
        let endDay = calendar.startOfDay(for: max(startDate, endDate))
        let upperBound = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay

        let expenseEntries = transactions.compactMap { transaction -> ReportCSVEntry? in
            guard transaction.date >= lowerBound, transaction.date < upperBound else {
                return nil
            }
            return ReportCSVEntry(
                type: .expense,
                date: transaction.date,
                description: transaction.transactionDescription,
                category: transaction.category.rawValue,
                amount: transaction.amount,
                currencyCode: currencyCode
            )
        }
        let incomeEntries = incomes.compactMap { income -> ReportCSVEntry? in
            guard income.date >= lowerBound, income.date < upperBound else {
                return nil
            }
            return ReportCSVEntry(
                type: .income,
                date: income.date,
                description: income.incomeDescription,
                category: income.category.rawValue,
                amount: income.amount,
                currencyCode: currencyCode
            )
        }
        return expenseEntries + incomeEntries
    }

    private var reportEntries: [ReportPDFEntry] {
        let calendar = Calendar.current
        let lowerBound = calendar.startOfDay(for: min(startDate, endDate))
        let upperDay = calendar.startOfDay(for: max(startDate, endDate))
        let upperBound = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDay

        let purchaseEntries = transactions.compactMap { transaction -> ReportPDFEntry? in
            let entryDate = transaction.dueDate ?? transaction.date
            guard entryDate >= lowerBound, entryDate < upperBound else { return nil }
            let status = transaction.effectivePaymentStatus()
            return ReportPDFEntry(
                kind: .expense,
                date: entryDate,
                title: transaction.transactionDescription.isEmpty
                    ? String(localized: "transaction.untitled", locale: locale)
                    : transaction.transactionDescription,
                amount: transaction.amount,
                status: statusTitle(status, kind: .expense),
                statusValue: status,
                category: spendingCategoryTitle(transaction.category)
            )
        }

        let incomeEntries = incomes.compactMap { income -> ReportPDFEntry? in
            let entryDate = income.dueDate ?? income.date
            guard entryDate >= lowerBound, entryDate < upperBound else { return nil }
            let status = income.effectivePaymentStatus()
            return ReportPDFEntry(
                kind: .income,
                date: entryDate,
                title: income.incomeDescription.isEmpty
                    ? String(localized: "income.untitled", locale: locale)
                    : income.incomeDescription,
                amount: income.amount,
                status: statusTitle(status, kind: .income),
                statusValue: status,
                category: incomeCategoryTitle(income.category)
            )
        }

        let fixedEntries = fixedExpenses.flatMap {
            fixedExpenseEntries(for: $0, from: lowerBound, through: upperDay)
        }
        let profileEntries = profiles.first.map {
            profileIncomeEntries(
                for: $0,
                registeredIncomes: incomes,
                from: lowerBound,
                through: upperDay
            )
        } ?? []

        return (purchaseEntries + incomeEntries + fixedEntries + profileEntries)
            .filter(matchesStatusFilter)
            .sorted(by: areInReportOrder)
    }

    var body: some View {
        Form {
            Section("Period") {
                DatePicker(
                    "From",
                    selection: $startDate,
                    in: ...endDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "To",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
            }

            Section("report.options") {
                Picker("Status", selection: $statusFilter) {
                    ForEach(ReportStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker("report.sort", selection: $sortOption) {
                    ForEach(ReportSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section("Summary") {
                reportRow(
                    title: "Income",
                    amount: summary.totalIncome,
                    color: AppStyle.accentColor
                )
                reportRow(
                    title: "Variable expenses",
                    amount: summary.totalVariableExpenses,
                    color: .primary
                )
                reportRow(
                    title: "Fixed expenses",
                    amount: summary.totalFixedExpenses,
                    color: .orange
                )
                reportRow(
                    title: "Planned savings",
                    amount: summary.plannedSavings,
                    color: .primary
                )
                reportRow(
                    title: "Net result",
                    amount: summary.netResult,
                    color: summary.netResult < 0 ? .red : AppStyle.accentColor
                )
                LabeledContent("Entries", value: "\(summary.entryCount)")
            }

            if !summary.variableExpenseCategories.isEmpty {
                Section("Variable expenses by category") {
                    ForEach(summary.variableExpenseCategories, id: \.category) { total in
                        reportRow(title: total.category.titleKey, amount: total.amount, color: .primary)
                    }
                }
            }

            if !summary.fixedExpenseCategories.isEmpty {
                Section("Fixed expenses by category") {
                    ForEach(summary.fixedExpenseCategories, id: \.category) { total in
                        reportRow(
                            title: fixedExpenseCategoryTitle(total.category),
                            amount: total.amount,
                            color: .orange
                        )
                    }
                }
            }

            Section {
                Button {
                    createPDFPreview()
                } label: {
                    Label("Preview PDF", systemImage: "doc.richtext")
                }

                ShareLink(
                    item: ReportCSVShareDocument(entries: csvEntries),
                    preview: SharePreview("SpendlyAI transactions")
                ) {
                    Label("Export CSV", systemImage: "tablecells")
                }
            }
        }
        .navigationTitle("Reports")
        .sheet(item: $pdfPreview) { preview in
            ReportPDFPreviewView(preview: preview)
        }
    }

    private func createPDFPreview() {
        let request = ReportPDFRequest(
            appName: appDisplayName,
            startDate: startDate,
            endDate: endDate,
            currencyCode: currencyCode,
            generatedAt: .now,
            summary: summary,
            entries: reportEntries,
            sortDescription: localizedString(sortOption.localizationKey),
            statusDescription: localizedString(statusFilter.localizationKey)
        )
        let data = ReportPDFGenerator().makePDF(for: request, locale: locale)
        pdfPreview = ReportPDFPreview(data: data)
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "SpendlyAI"
    }

    private func reportRow(
        title: LocalizedStringKey,
        amount: Decimal,
        color: Color
    ) -> some View {
        LabeledContent {
            Text(MoneyFormatter.string(from: amount, currencyCode: currencyCode))
                .foregroundStyle(color)
        } label: {
            Text(title)
        }
    }

    private func matchesStatusFilter(_ entry: ReportPDFEntry) -> Bool {
        switch statusFilter {
        case .all:
            true
        case .paid:
            entry.statusValue == .settled || entry.statusValue == .withdrawn
        case .pending:
            entry.statusValue == .pending
        case .overdue:
            entry.statusValue == .overdue
        }
    }

    private func areInReportOrder(_ first: ReportPDFEntry, _ second: ReportPDFEntry) -> Bool {
        switch sortOption {
        case .dateAscending:
            first.date == second.date
                ? first.title.localizedStandardCompare(second.title) == .orderedAscending
                : first.date < second.date
        case .dateDescending:
            first.date == second.date
                ? first.title.localizedStandardCompare(second.title) == .orderedAscending
                : first.date > second.date
        case .amountDescending:
            first.amount == second.amount
                ? first.date < second.date
                : first.amount > second.amount
        }
    }

    private func profileIncomeEntries(
        for profile: UserFinancialProfile,
        registeredIncomes: [Income],
        from startDate: Date,
        through endDate: Date
    ) -> [ReportPDFEntry] {
        guard profile.monthlyNetIncome > 0 else { return [] }

        let calendar = Calendar.current
        guard var incomeDate = firstDueDate(
            day: profile.paydayDay,
            onOrAfter: startDate,
            calendar: calendar
        ) else { return [] }

        var entries: [ReportPDFEntry] = []
        while incomeDate <= endDate {
            let isAlreadyRegistered = registeredIncomes.contains { income in
                income.category == .salary
                    && calendar.isDate(income.dueDate ?? income.date, inSameDayAs: incomeDate)
            }

            if !isAlreadyRegistered {
                let status: PaymentStatus = incomeDate <= .now ? .settled : .pending
                entries.append(ReportPDFEntry(
                    kind: .income,
                    date: incomeDate,
                    title: localizedString("report.profileIncome"),
                    amount: profile.monthlyNetIncome,
                    status: statusTitle(status, kind: .income),
                    statusValue: status,
                    category: localizedString("category.income")
                ))
            }

            guard let nextDate = calendar.date(byAdding: .month, value: 1, to: incomeDate) else {
                break
            }
            incomeDate = nextDate
        }
        return entries
    }

    private func fixedExpenseEntries(
        for expense: FixedExpense,
        from startDate: Date,
        through endDate: Date
    ) -> [ReportPDFEntry] {
        guard expense.isActive else { return [] }

        let calendar = Calendar.current
        var occurrence = expense.dueDate ?? firstDueDate(
            day: expense.dueDay,
            onOrAfter: startDate,
            calendar: calendar
        )
        guard var occurrence else { return [] }

        while occurrence < startDate {
            guard let next = nextOccurrence(
                after: occurrence,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths,
                calendar: calendar
            ) else { return [] }
            occurrence = next
        }

        var entries: [ReportPDFEntry] = []
        while occurrence <= endDate {
            let isOriginalOccurrence = expense.dueDate.map {
                calendar.isDate($0, inSameDayAs: occurrence)
            } ?? false
            let status = isOriginalOccurrence
                ? expense.effectivePaymentStatus()
                : PaymentStatus.pending.effectiveStatus(dueDate: occurrence)

            entries.append(ReportPDFEntry(
                kind: .expense,
                date: occurrence,
                title: expense.name,
                amount: expense.amount,
                status: statusTitle(status, kind: .expense),
                statusValue: status,
                category: localizedFixedExpenseCategoryTitle(expense.category)
            ))

            guard let next = nextOccurrence(
                after: occurrence,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths,
                calendar: calendar
            ), next > occurrence else { break }
            occurrence = next
        }
        return entries
    }

    private func firstDueDate(day: Int, onOrAfter date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(max(day, 1), 28)
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate >= date
            ? candidate
            : calendar.date(byAdding: .month, value: 1, to: candidate)
    }

    private func nextOccurrence(
        after date: Date,
        recurrence: ExpenseRecurrence,
        customMonths: Int,
        calendar: Calendar
    ) -> Date? {
        switch recurrence {
        case .weekly: calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual: calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        case .custom: calendar.date(byAdding: .month, value: max(customMonths, 1), to: date)
        }
    }

    private func statusTitle(_ status: PaymentStatus, kind: PaymentKind) -> String {
        let key: String
        switch status {
        case .pending: key = "paymentStatus.pending"
        case .withdrawn: key = "paymentStatus.withdrawn"
        case .settled:
            key = kind == .income ? "paymentStatus.received" : "paymentStatus.paid"
        case .overdue: key = "paymentStatus.overdue"
        }
        return localizedString(key)
    }

    private func spendingCategoryTitle(_ category: SpendingCategory) -> String {
        localizedString(categoryLocalizationKey(category))
    }

    private func localizedFixedExpenseCategoryTitle(_ category: ExpenseCategory) -> String {
        localizedString(fixedExpenseCategoryLocalizationKey(category))
    }

    private func incomeCategoryTitle(_ category: IncomeCategory) -> String {
        let key: String
        switch category.normalizedCategory {
        case .subscriptions: key = "category.subscriptions"
        case .other: key = "category.other"
        case .groceries: key = "category.groceries"
        case .insurance: key = "category.insurance"
        case .gifts: key = "category.gifts"
        case .health: key = "category.health"
        case .home: key = "category.home"
        case .income: key = "category.income"
        case .clothing: key = "category.clothing"
        case .communication: key = "category.communication"
        case .gambling: key = "category.gambling"
        case .savings: key = "category.savings"
        case .transport: key = "category.transport"
        case .withdrawals: key = "category.withdrawals"
        case .entertainment: key = "category.entertainment"
        case .developer: key = "category.developer"
        case .salary, .freelance, .benefits, .investment, .gift, .refund:
            key = "category.income"
        }
        return localizedString(key)
    }

    private func categoryLocalizationKey(_ category: SpendingCategory) -> String {
        switch category {
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
        case .food: "category.food"
        case .shopping: "category.shopping"
        case .bills: "category.bills"
        }
    }

    private func localizedString(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    private func fixedExpenseCategoryTitle(_ category: ExpenseCategory) -> LocalizedStringKey {
        LocalizedStringKey(fixedExpenseCategoryLocalizationKey(category))
    }

    private func fixedExpenseCategoryLocalizationKey(_ category: ExpenseCategory) -> String {
        switch category {
        case .subscriptions: "expenseCategory.subscriptions"
        case .other: "expenseCategory.other"
        case .groceries: "expenseCategory.groceries"
        case .insurance: "expenseCategory.insurance"
        case .gifts: "category.gifts"
        case .health: "expenseCategory.health"
        case .housing: "expenseCategory.housing"
        case .income: "category.income"
        case .clothing: "category.clothing"
        case .communication: "category.communication"
        case .gambling: "expenseCategory.gambling"
        case .savings: "category.savings"
        case .transport: "expenseCategory.transport"
        case .withdrawals: "category.withdrawals"
        case .entertainment: "category.entertainment"
        case .developer: "category.developer"
        case .utilities: "expenseCategory.utilities"
        case .debt: "expenseCategory.debt"
        case .childcare: "expenseCategory.childcare"
        }
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
}
