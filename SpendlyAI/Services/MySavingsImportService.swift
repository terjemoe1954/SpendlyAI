import Foundation
import SwiftData

struct MySavingsImportPlan: Identifiable, Equatable, Sendable {
    let id = UUID()
    let exportedAt: Date
    let formatVersion: Int
    let expenses: [Expense]
    let incomes: [ImportedIncome]
    let fixedExpenses: [ImportedFixedExpense]
    let skippedCount: Int

    struct Expense: Equatable, Sendable {
        let amount: Decimal
        let date: Date
        let category: SpendingCategory
        let title: String
        let notes: String?
        let dueDate: Date?
        let settledDate: Date?
        let paymentStatus: PaymentStatus
    }

    struct ImportedFixedExpense: Equatable, Sendable {
        let name: String
        let amount: Decimal
        let dueDay: Int
        let category: ExpenseCategory
        let recurrence: ExpenseRecurrence
        let customRecurrenceMonths: Int
        let dueDate: Date?
    }

    struct ImportedIncome: Equatable, Sendable {
        let amount: Decimal
        let date: Date
        let category: IncomeCategory
        let title: String
        let notes: String?
        let recurrence: IncomeRecurrence
        let isActive: Bool
        let dueDate: Date?
        let settledDate: Date?
        let paymentStatus: PaymentStatus
    }

    var totalCount: Int {
        expenses.count + incomes.count + fixedExpenses.count
    }
}

enum MySavingsImportError: Error, Equatable {
    case unreadableFile
    case unsupportedVersion(Int)
    case noImportableTransactions
}

struct MySavingsImportService {
    private struct FilePayload: Decodable {
        let formatVersion: Int
        let exportedAt: Date
        let categories: [Category]
        let transactions: [SourceTransaction]
    }

    private struct Category: Decodable {
        let id: String
        let name: String
    }

    private struct SourceTransaction: Decodable {
        let amount: String
        let category: String
        let createdAt: Date
        let dueDate: Date?
        let isArchived: Bool
        let isCompleted: Bool
        let notes: String
        let paidDate: Date?
        let recurrence: String
        let recurrenceAnchorDay: Int?
        let status: String
        let title: String
        let type: String
    }

    func decode(_ data: Data) throws -> MySavingsImportPlan {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: FilePayload
        do {
            payload = try decoder.decode(FilePayload.self, from: data)
        } catch {
            throw MySavingsImportError.unreadableFile
        }

        guard payload.formatVersion == 4 else {
            throw MySavingsImportError.unsupportedVersion(payload.formatVersion)
        }

        let categoryNames = Dictionary(
            uniqueKeysWithValues: payload.categories.map { ($0.id, $0.name) }
        )
        var expenses: [MySavingsImportPlan.Expense] = []
        var incomes: [MySavingsImportPlan.ImportedIncome] = []
        var fixedExpenses: [MySavingsImportPlan.ImportedFixedExpense] = []
        var skippedCount = 0

        for item in payload.transactions where !item.isArchived {
            guard let amount = MoneyParser.decimal(from: item.amount), amount >= 0 else {
                skippedCount += 1
                continue
            }

            let sourceCategory = categoryNames[item.category] ?? item.category
            let notes = preservedNotes(item.notes, sourceCategory: sourceCategory)
            let status = paymentStatus(for: item)
            let date = item.dueDate ?? item.createdAt
            let settledDate = item.paidDate ?? (item.isCompleted ? date : nil)

            switch item.type.lowercased() {
            case "expense":
                if isUpcomingRecurringExpense(item) {
                    let recurrence = expenseRecurrence(for: item)
                    fixedExpenses.append(.init(
                        name: fixedExpenseName(item.title),
                        amount: amount,
                        dueDay: item.recurrenceAnchorDay ?? Calendar.current.component(.day, from: date),
                        category: expenseCategory(for: sourceCategory),
                        recurrence: recurrence.value,
                        customRecurrenceMonths: recurrence.customMonths,
                        dueDate: item.dueDate
                    ))
                } else {
                    expenses.append(.init(
                        amount: amount,
                        date: date,
                        category: spendingCategory(for: sourceCategory),
                        title: item.title,
                        notes: notes,
                        dueDate: item.dueDate,
                        settledDate: settledDate,
                        paymentStatus: status
                    ))
                }
            case "income":
                let isHistoricalIncome = status == .settled
                incomes.append(.init(
                    amount: amount,
                    date: date,
                    category: incomeCategory(for: sourceCategory),
                    title: item.title,
                    notes: notes,
                    // MySavings exports every received occurrence separately. Only its
                    // upcoming pending occurrence should generate future income dates.
                    recurrence: isHistoricalIncome ? .oneTime : incomeRecurrence(for: item.recurrence),
                    isActive: true,
                    dueDate: item.dueDate,
                    settledDate: settledDate,
                    paymentStatus: status
                ))
            default:
                skippedCount += 1
            }
        }

        guard !expenses.isEmpty || !incomes.isEmpty || !fixedExpenses.isEmpty else {
            throw MySavingsImportError.noImportableTransactions
        }

        return MySavingsImportPlan(
            exportedAt: payload.exportedAt,
            formatVersion: payload.formatVersion,
            expenses: expenses,
            incomes: incomes,
            fixedExpenses: fixedExpenses,
            skippedCount: skippedCount
        )
    }

    @MainActor
    func importPlan(_ plan: MySavingsImportPlan, into modelContext: ModelContext) throws {
        do {
            try modelContext.transaction {
                for item in plan.expenses {
                    modelContext.insert(Transaction(
                        amount: item.amount,
                        date: item.date,
                        category: item.category,
                        transactionDescription: item.title,
                        notes: item.notes,
                        dueDate: item.dueDate,
                        settledDate: item.settledDate,
                        paymentStatus: item.paymentStatus
                    ))
                }

                for item in plan.fixedExpenses {
                    modelContext.insert(FixedExpense(
                        name: item.name,
                        amount: item.amount,
                        dueDay: item.dueDay,
                        category: item.category,
                        recurrence: item.recurrence,
                        customRecurrenceMonths: item.customRecurrenceMonths,
                        isActive: true,
                        dueDate: item.dueDate,
                        paymentStatus: .pending
                    ))
                }

                for item in plan.incomes {
                    modelContext.insert(Income(
                        amount: item.amount,
                        date: item.date,
                        category: item.category,
                        incomeDescription: item.title,
                        notes: item.notes,
                        recurrence: item.recurrence,
                        isActive: item.isActive,
                        dueDate: item.dueDate,
                        settledDate: item.settledDate,
                        paymentStatus: item.paymentStatus
                    ))
                }
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func paymentStatus(for item: SourceTransaction) -> PaymentStatus {
        if item.isCompleted || ["paid", "received"].contains(item.status.lowercased()) {
            return .settled
        }
        return .pending
    }

    private func isUpcomingRecurringExpense(_ item: SourceTransaction) -> Bool {
        item.recurrence.lowercased() != "none"
            && !item.isCompleted
            && item.status.lowercased() == "pending"
    }

    private func fixedExpenseName(_ title: String) -> String {
        title.replacingOccurrences(
            of: "Copy of ",
            with: "",
            options: [.anchored, .caseInsensitive]
        )
    }

    private func expenseRecurrence(
        for item: SourceTransaction
    ) -> (value: ExpenseRecurrence, customMonths: Int) {
        let normalizedNotes = normalized(item.notes)
        if normalizedNotes.contains("12 maneder") {
            return (.yearly, 12)
        }
        if normalizedNotes.contains("6 maneder") {
            return (.semiannual, 6)
        }
        if normalizedNotes.contains("3 maneder") {
            return (.quarterly, 3)
        }

        switch item.recurrence.lowercased() {
        case "weekly":
            return (.weekly, 1)
        case "biweekly":
            return (.biweekly, 1)
        case "quarterly":
            return (.quarterly, 3)
        case "semiannual":
            return (.semiannual, 6)
        case "yearly", "annual":
            return (.yearly, 12)
        default:
            return (.monthly, 1)
        }
    }

    private func incomeRecurrence(for value: String) -> IncomeRecurrence {
        switch value.lowercased() {
        case "weekly": .weekly
        case "biweekly": .biweekly
        case "monthly": .monthly
        case "quarterly": .quarterly
        case "yearly", "annual": .yearly
        default: .oneTime
        }
    }

    private func spendingCategory(for name: String) -> SpendingCategory {
        switch normalized(name) {
        case "abbonementer", "abonnementer": .subscriptions
        case "bolig strom", "hjem": .home
        case "dagligvarer": .groceries
        case "forsikring": .insurance
        case "gaver": .gifts
        case "helse": .health
        case "hobby utvikling", "apputvikling": .developer
        case "klaer", "klaer sko": .clothing
        case "lonn inntekt", "inntekt", "inntekter": .income
        case "pengespill": .gambling
        case "refusjon": .refund
        case "skatt avgifter", "trekk": .withdrawals
        case "sparing": .savings
        case "spise ute": .diningOut
        case "telefon internett", "kommunikasjon": .communication
        case "transport": .transport
        case "fritid ferie", "underholdning": .entertainment
        default: .other
        }
    }

    private func expenseCategory(for name: String) -> ExpenseCategory {
        switch spendingCategory(for: name) {
        case .subscriptions: .subscriptions
        case .other: .other
        case .groceries: .groceries
        case .insurance: .insurance
        case .gifts: .gifts
        case .health: .health
        case .home: .housing
        case .income: .income
        case .clothing: .clothing
        case .communication: .communication
        case .gambling: .gambling
        case .savings: .savings
        case .transport: .transport
        case .withdrawals: .withdrawals
        case .entertainment: .entertainment
        case .developer: .developer
        case .diningOut: .diningOut
        case .refund: .refund
        case .balanceAdjustment: .balanceAdjustment
        case .food, .shopping, .bills: .other
        }
    }

    private func incomeCategory(for name: String) -> IncomeCategory {
        switch spendingCategory(for: name) {
        case .subscriptions: .subscriptions
        case .other: .other
        case .groceries: .groceries
        case .insurance: .insurance
        case .gifts: .gifts
        case .health: .health
        case .home: .home
        case .income: .income
        case .clothing: .clothing
        case .communication: .communication
        case .gambling: .gambling
        case .savings: .savings
        case .transport: .transport
        case .withdrawals: .withdrawals
        case .entertainment: .entertainment
        case .developer: .developer
        case .diningOut: .diningOut
        case .refund: .refund
        case .balanceAdjustment: .balanceAdjustment
        case .food, .shopping, .bills: .other
        }
    }

    private func preservedNotes(_ notes: String, sourceCategory: String) -> String? {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard spendingCategory(for: sourceCategory) == .other,
              normalized(sourceCategory) != "annet",
              normalized(sourceCategory) != "other" else {
            return cleanNotes.isEmpty ? nil : cleanNotes
        }

        let categoryNote = "Opprinnelig MySavings-kategori: \(sourceCategory)"
        return cleanNotes.isEmpty ? categoryNote : "\(cleanNotes)\n\(categoryNote)"
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nb_NO"))
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }
}
