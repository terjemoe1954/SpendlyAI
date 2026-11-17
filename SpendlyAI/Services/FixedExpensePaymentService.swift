import Foundation
import SwiftData

struct FixedExpensePayment: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let dueDate: Date
    var paymentDate: Date
    let amount: Decimal
    let name: String
    let category: ExpenseCategory
    let customCategoryName: String?
}

// All payment entry points use the same occurrence and persistence rules.
@MainActor
enum FixedExpensePaymentService {
    enum PaymentError: Error { case occurrenceChanged, invalidSchedule }

    nonisolated static func currentDueDate(for expense: FixedExpense, now: Date = .now, calendar: Calendar = .current) -> Date {
        if let date = expense.dueDate { return calendar.startOfDay(for: date) }
        let today = calendar.startOfDay(for: now)
        let thisMonth = date(inMonthOf: today, day: expense.dueDay, calendar: calendar)
        if thisMonth >= today { return thisMonth }
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth) ?? thisMonth
        return date(inMonthOf: nextMonth, day: expense.dueDay, calendar: calendar)
    }

    nonisolated static func nextDueDate(after date: Date, for expense: FixedExpense, calendar: Calendar = .current) -> Date? {
        nextDueDate(after: date, dueDay: expense.dueDay, recurrence: expense.recurrence,
                    customMonths: expense.customRecurrenceMonths, calendar: calendar)
    }

    nonisolated static func nextDueDate(after date: Date, dueDay: Int, recurrence: ExpenseRecurrence,
                                       customMonths: Int, calendar: Calendar) -> Date? {
        switch recurrence {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date)
        default:
            let months: Int
            switch recurrence {
            case .quarterly: months = 3
            case .semiannual: months = 6
            case .yearly: months = 12
            case .custom: months = max(customMonths, 1)
            default: months = 1
            }
            guard let next = calendar.date(byAdding: .month, value: months, to: date) else { return nil }
            return self.date(inMonthOf: next, day: dueDay, calendar: calendar)
        }
    }

    private nonisolated static func date(inMonthOf date: Date, day: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(max(day, 1), calendar.range(of: .day, in: .month, for: date)?.count ?? 28)
        return calendar.date(from: components) ?? date
    }

    nonisolated static func unpaidDates(for expense: FixedExpense, from start: Date, through end: Date,
                            calendar: Calendar = .current) -> [Date] {
        guard expense.isActive else { return [] }
        var due = currentDueDate(for: expense, now: start, calendar: calendar)
        var dates: [Date] = []
        while due <= end {
            if due >= start { dates.append(due) }
            guard let next = nextDueDate(after: due, for: expense, calendar: calendar), next > due else { break }
            due = next
        }
        return dates
    }

    nonisolated static func history(for expense: FixedExpense) throws -> [FixedExpensePayment] {
        guard let data = expense.paymentHistoryData else { return [] }
        return try JSONDecoder().decode([FixedExpensePayment].self, from: data)
    }

    static func recordPayment(for expense: FixedExpense, dueDate: Date, paymentDate: Date,
                              context: ModelContext, calendar: Calendar = .current) throws {
        var records = try history(for: expense)
        guard calendar.isDate(currentDueDate(for: expense, calendar: calendar), inSameDayAs: dueDate),
              !records.contains(where: { calendar.isDate($0.dueDate, inSameDayAs: dueDate) }) else {
            throw PaymentError.occurrenceChanged
        }
        guard let next = nextDueDate(after: dueDate, for: expense, calendar: calendar), next > dueDate else {
            throw PaymentError.invalidSchedule
        }
        records.append(FixedExpensePayment(dueDate: dueDate, paymentDate: paymentDate,
                                          amount: expense.amount, name: expense.name,
                                          category: expense.category, customCategoryName: expense.customCategoryName))
        let data = try JSONEncoder().encode(records)
        let previous = (expense.paymentHistoryData, expense.dueDate, expense.settledDate, expense.paymentStatusRawValue)
        expense.paymentHistoryData = data
        expense.dueDate = next
        expense.paymentStatus = .pending
        expense.settledDate = nil
        do { try context.save() }
        catch {
            (expense.paymentHistoryData, expense.dueDate, expense.settledDate, expense.paymentStatusRawValue) = previous
            throw error
        }
    }

    static func changePaymentDate(for expense: FixedExpense, paymentID: UUID, date: Date, context: ModelContext) throws {
        var records = try history(for: expense)
        guard let index = records.firstIndex(where: { $0.id == paymentID }) else { throw PaymentError.occurrenceChanged }
        records[index].paymentDate = date
        let previous = expense.paymentHistoryData
        expense.paymentHistoryData = try JSONEncoder().encode(records)
        do { try context.save() }
        catch { expense.paymentHistoryData = previous; throw error }
    }

    // Explicit payments from build 30 become occurrence history once. No unpaid dates are skipped.
    static func migrateLegacyPayments(context: ModelContext) throws {
        for expense in try context.fetch(FetchDescriptor<FixedExpense>()) where expense.isActive {
            guard expense.paymentStatusRawValue == PaymentStatus.settled.rawValue,
                  let dueDate = expense.dueDate, let paymentDate = expense.settledDate else { continue }
            try recordPayment(for: expense, dueDate: dueDate, paymentDate: paymentDate, context: context)
        }
    }
}
