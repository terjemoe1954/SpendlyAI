import SwiftData
import SwiftUI

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
            summary: summary
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

    private func fixedExpenseCategoryTitle(_ category: ExpenseCategory) -> LocalizedStringKey {
        switch category {
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
}

#Preview {
    NavigationStack {
        ReportsView()
    }
}
