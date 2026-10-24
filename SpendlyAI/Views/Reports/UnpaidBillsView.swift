import SwiftData
import SwiftUI
import UIKit

struct UnpaidBillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @Query private var transactions: [Transaction]
    @Query private var fixedExpenses: [FixedExpense]
    @Query(sort: \UserFinancialProfile.updatedAt, order: .reverse) private var profiles: [UserFinancialProfile]

    let overdueOnly: Bool

    init(overdueOnly: Bool = false) {
        self.overdueOnly = overdueOnly
    }

    private var currencyCode: String {
        profiles.first?.currencyCode ?? Locale.current.currency?.identifier ?? "NOK"
    }

    private var bills: [UnpaidBill] {
        let purchaseBills = transactions.compactMap { transaction -> UnpaidBill? in
            let status = transaction.effectivePaymentStatus()
            guard status == .pending || status == .overdue,
                  !overdueOnly || status == .overdue else { return nil }
            return UnpaidBill(transaction: transaction)
        }
        let recurringBills = fixedExpenses.compactMap { expense -> UnpaidBill? in
            guard expense.isActive, let dueDate = expense.dueDate else { return nil }
            let status = expense.paymentStatus.effectiveStatus(dueDate: dueDate)
            guard status == .pending || status == .overdue,
                  !overdueOnly || status == .overdue else { return nil }
            return UnpaidBill(fixedExpense: expense, dueDate: dueDate, status: status)
        }
        return (purchaseBills + recurringBills).sorted {
            if $0.dueDate == $1.dueDate { return $0.title < $1.title }
            return $0.dueDate < $1.dueDate
        }
    }

    private var total: Decimal {
        bills.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("unpaid.summary.count", value: String(bills.count))
                LabeledContent(
                    "unpaid.summary.total",
                    value: MoneyFormatter.string(from: total, currencyCode: currencyCode, locale: locale)
                )
            }

            Section {
                if bills.isEmpty {
                    ContentUnavailableView(
                        "unpaid.empty.title",
                        systemImage: "checkmark.circle",
                        description: Text("unpaid.empty.message")
                    )
                } else {
                    ForEach(bills) { bill in
                        UnpaidBillRow(
                            bill: bill,
                            currencyCode: currencyCode,
                            markPaid: { markPaid(bill) }
                        )
                    }
                }
            } header: {
                Text(overdueOnly ? "unpaid.overdue.section" : "unpaid.all.section")
            }
        }
        .navigationTitle(overdueOnly ? "unpaid.overdue.title" : "unpaid.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: printBills) {
                    Label("unpaid.print", systemImage: "printer")
                }
                .disabled(bills.isEmpty)
            }
        }
    }

    private func markPaid(_ bill: UnpaidBill) {
        let paymentDate = Date.now
        switch bill.source {
        case .transaction(let transaction):
            transaction.paymentStatus = .settled
            transaction.settledDate = paymentDate
        case .fixedExpense(let expense):
            expense.settledDate = paymentDate
            if let nextDate = nextOccurrence(after: bill.dueDate, expense: expense) {
                expense.dueDate = nextDate
                expense.paymentStatus = .pending
            } else {
                expense.paymentStatus = .settled
                expense.isActive = false
            }
        }
        try? modelContext.save()
    }

    private func printBills() {
        let entries = bills.map {
            UnpaidBillPrintEntry(
                title: $0.title.isEmpty ? String(localized: "transaction.untitled", locale: locale) : $0.title,
                amount: $0.amount,
                dueDate: $0.dueDate
            )
        }
        let pdf = UnpaidBillsPDFGenerator().makePDF(
            entries: entries,
            currencyCode: currencyCode,
            locale: locale
        )
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = String(localized: "unpaid.title", locale: locale)
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = pdf
        controller.present(animated: true)
    }

    private func nextOccurrence(after date: Date, expense: FixedExpense) -> Date? {
        let calendar = Calendar.current
        switch expense.recurrence {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual:
            return calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .custom:
            return calendar.date(byAdding: .month, value: max(expense.customRecurrenceMonths, 1), to: date)
        }
    }
}

private struct UnpaidBill: Identifiable {
    enum Source {
        case transaction(Transaction)
        case fixedExpense(FixedExpense)
    }

    let id: String
    let title: String
    let amount: Decimal
    let dueDate: Date
    let status: PaymentStatus
    let source: Source

    init(transaction: Transaction) {
        id = "transaction-\(transaction.persistentModelID)"
        title = transaction.transactionDescription
        amount = transaction.amount
        dueDate = transaction.dueDate ?? transaction.date
        status = transaction.effectivePaymentStatus()
        source = .transaction(transaction)
    }

    init(fixedExpense: FixedExpense, dueDate: Date, status: PaymentStatus) {
        id = "fixed-\(fixedExpense.persistentModelID)"
        title = fixedExpense.name
        amount = fixedExpense.amount
        self.dueDate = dueDate
        self.status = status
        source = .fixedExpense(fixedExpense)
    }
}

private struct UnpaidBillRow: View {
    @Environment(\.locale) private var locale

    let bill: UnpaidBill
    let currencyCode: String
    let markPaid: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: markPaid) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(AppStyle.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("unpaid.markPaid")

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.title.isEmpty ? String(localized: "transaction.untitled") : bill.title)
                    .font(.body.weight(.medium))
                HStack {
                    Text(bill.dueDate, format: .dateTime.day().month().year())
                    Text(bill.status.titleKey(for: .expense))
                        .foregroundStyle(bill.status.displayColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(MoneyFormatter.string(from: bill.amount, currencyCode: currencyCode, locale: locale))
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 3)
    }
}
