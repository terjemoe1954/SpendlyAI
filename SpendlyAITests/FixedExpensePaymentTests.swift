import Foundation
import SwiftData
import Testing
@testable import SpendlyAI

@MainActor
struct FixedExpensePaymentTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }
    private func store() throws -> ModelContainer {
        try ModelContainer(for: FixedExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private func bill(due: Date, day: Int = 15, recurrence: ExpenseRecurrence = .monthly) -> FixedExpense {
        FixedExpense(name: "Husleie", amount: 1000, dueDay: day, category: .housing,
                     recurrence: recurrence, dueDate: due, paymentStatus: .pending)
    }

    @Test func paymentBelongsToDueMonthAndNextMonthIsUnpaid() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15),
            paymentDate: date(2026, 11, 18), context: context, calendar: calendar)
        #expect(expense.dueDate == date(2026, 12, 15))
        #expect(expense.paymentStatus == .pending)
        #expect(expense.settledDate == nil)
        #expect(expense.isActive)
        #expect(expense.paymentHistory.count == 1)
        #expect(expense.paymentHistory[0].dueDate == date(2026, 11, 15))
        #expect(expense.paymentHistory[0].paymentDate == date(2026, 11, 18))
        let reopened = ModelContext(container)
        let saved = try #require(reopened.fetch(FetchDescriptor<FixedExpense>()).first)
        #expect(saved.dueDate == date(2026, 12, 15))
        #expect(saved.paymentHistory == expense.paymentHistory)
    }

    @Test func lateAndEarlyPaymentsDoNotMoveTheScheduleToPaymentDay() throws {
        for paid in [date(2026, 10, 2), date(2027, 1, 3)] {
            let container = try store(), context = container.mainContext
            let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
            try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15),
                paymentDate: paid, context: context, calendar: calendar)
            #expect(expense.dueDate == date(2026, 12, 15))
        }
    }

    @Test func overdueDatesAreNotSilentlySkipped() {
        let expense = bill(due: date(2026, 9, 15))
        #expect(FixedExpensePaymentService.currentDueDate(for: expense, now: date(2026, 11, 20), calendar: calendar) == date(2026, 9, 15))
        #expect(expense.effectivePaymentStatus(now: date(2026, 11, 20), calendar: calendar) == .overdue)
    }

    @Test func monthEndReturnsToOriginalDayAfterFebruary() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2027, 1, 31), day: 31); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2027, 1, 31), paymentDate: date(2027, 1, 30), context: context, calendar: calendar)
        #expect(expense.dueDate == date(2027, 2, 28))
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2027, 2, 28), paymentDate: date(2027, 2, 28), context: context, calendar: calendar)
        #expect(expense.dueDate == date(2027, 3, 31))
        #expect(expense.paymentHistory.count == 2)
    }

    @Test func supportsQuarterlyAnnualAndCustomIntervals() throws {
        for (recurrence, expected) in [(ExpenseRecurrence.quarterly, date(2027, 2, 15)), (.semiannual, date(2027, 5, 15)), (.yearly, date(2027, 11, 15)), (.custom, date(2027, 3, 15)), (.weekly, date(2026, 11, 22)), (.biweekly, date(2026, 11, 29))] {
            let expense = bill(due: date(2026, 11, 15), recurrence: recurrence)
            expense.customRecurrenceMonths = 4
            #expect(FixedExpensePaymentService.nextDueDate(after: date(2026, 11, 15), for: expense, calendar: calendar) == expected)
        }
    }

    @Test func staleSecondTapCannotPayTheNextMonth() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        #expect(throws: FixedExpensePaymentService.PaymentError.self) {
            try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        }
        #expect(expense.paymentHistory.count == 1)
        #expect(expense.dueDate == date(2026, 12, 15))
    }

    @Test func editingPaidDateDoesNotShiftNextDueDate() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        try FixedExpensePaymentService.changePaymentDate(for: expense, paymentID: expense.paymentHistory[0].id, date: date(2026, 11, 17), context: context)
        #expect(expense.paymentHistory[0].paymentDate == date(2026, 11, 17))
        #expect(expense.dueDate == date(2026, 12, 15))
    }

    @Test func migratesBuild30PaymentsExactlyOnceAndKeepsInactiveBills() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); expense.paymentStatus = .settled
        expense.settledDate = date(2026, 11, 16); context.insert(expense)
        let inactive = bill(due: date(2026, 11, 15)); inactive.isActive = false
        inactive.paymentStatus = .settled; inactive.settledDate = date(2026, 11, 16); context.insert(inactive)
        try context.save()
        try FixedExpensePaymentService.migrateLegacyPayments(context: context)
        try FixedExpensePaymentService.migrateLegacyPayments(context: context)
        #expect(expense.paymentHistory.count == 1)
        #expect(expense.dueDate == date(2026, 12, 15))
        #expect(inactive.paymentHistory.isEmpty)
        #expect(!inactive.isActive)
    }

    @Test func reportsCountPaidOccurrenceOnceAndKeepHistoryAfterDeactivation() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        for active in [true, false] {
            expense.isActive = active
            let summary = ReportSummaryService().makeSummary(transactions: [], incomes: [], fixedExpenses: [expense], startDate: date(2026, 11, 1), endDate: date(2026, 11, 30), calendar: calendar)
            #expect(summary.totalFixedExpenses == 1000)
            #expect(summary.entryCount == 1)
        }
    }

    @Test func backupRoundTripPreservesPaymentHistoryAndNextDueDate() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        let backup = BackupService().makeBackup(profile: nil, transactions: [], fixedExpenses: [expense], savingsGoals: [])
        let decoded = try JSONDecoder().decode(SpendlyBackup.self, from: JSONEncoder().encode(backup))
        #expect(decoded.fixedExpenses[0].paymentHistoryData == expense.paymentHistoryData)
        #expect(decoded.fixedExpenses[0].dueDate == date(2026, 12, 15))
        let schema = Schema([UserFinancialProfile.self, SpendlyAI.Transaction.self, Income.self,
                             FixedExpense.self, SavingsGoal.self, CustomCategory.self])
        let restoredStore = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        try BackupService().restore(decoded, in: restoredStore.mainContext)
        let restored = try #require(restoredStore.mainContext.fetch(FetchDescriptor<FixedExpense>()).first)
        #expect(restored.paymentHistory == expense.paymentHistory)
        #expect(restored.dueDate == date(2026, 12, 15))
        var oldJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? [String: Any])
        var oldExpenses = try #require(oldJSON["fixedExpenses"] as? [[String: Any]])
        oldExpenses[0].removeValue(forKey: "paymentHistoryData")
        oldJSON["fixedExpenses"] = oldExpenses
        let oldBackup = try JSONDecoder().decode(SpendlyBackup.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        #expect(oldBackup.fixedExpenses[0].paymentHistoryData == nil)

    }
    @Test func paidFixedOccurrenceIsNotReservedOrDeductedTwice() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        let profile = UserFinancialProfile(monthlyNetIncome: 10000, paydayDay: 30,
            budgetPeriodStart: date(2026, 11, 1), budgetPeriodEnd: date(2026, 11, 30))
        let service = BudgetService(calendar: calendar)
        let input = service.makeInput(profile: profile, fixedExpenses: [expense], savingsGoals: [], transactions: [], today: date(2026, 11, 16))
        let result = service.calculateBudget(for: input, today: date(2026, 11, 16))
        #expect(result.upcomingFixedExpenses == 0)
        #expect(result.disposableAmount == 9000)
    }

    @Test func invalidHistoryCannotBeOverwrittenByAnotherPayment() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        let invalid = Data("not valid history".utf8)
        expense.paymentHistoryData = invalid
        #expect(throws: (any Error).self) {
            try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 15), context: context, calendar: calendar)
        }
        #expect(expense.paymentHistoryData == invalid)
        #expect(expense.dueDate == date(2026, 11, 15))
    }

    @Test func leapYearAndYearBoundaryKeepOriginalDueDay() {
        let expense = bill(due: date(2027, 12, 31), day: 31)
        #expect(FixedExpensePaymentService.nextDueDate(after: date(2027, 12, 31), for: expense, calendar: calendar) == date(2028, 1, 31))
        #expect(FixedExpensePaymentService.nextDueDate(after: date(2028, 1, 31), for: expense, calendar: calendar) == date(2028, 2, 29))
        #expect(FixedExpensePaymentService.nextDueDate(after: date(2028, 2, 29), for: expense, calendar: calendar) == date(2028, 3, 31))
    }

    @Test func dashboardAndStatisticsKeepPaidMonthAfterRolloverAndDeactivation() throws {
        let container = try store(), context = container.mainContext
        let expense = bill(due: date(2026, 11, 15)); context.insert(expense)
        try FixedExpensePaymentService.recordPayment(for: expense, dueDate: date(2026, 11, 15), paymentDate: date(2026, 11, 17), context: context, calendar: calendar)
        let interval = DateInterval(start: date(2026, 11, 1), end: date(2026, 12, 1))
        for active in [true, false] {
            expense.isActive = active
            let summary = DashboardSummaryCalculator(calendar: calendar).summary(transactions: [], incomes: [], fixedExpenses: [expense], interval: interval, now: date(2026, 11, 17))
            #expect(summary.totalExpenses == 1000)
            #expect(summary.entryCount == 1)
            let entries = StatisticsCalculator().entries(transactions: [], incomes: [], fixedExpenses: [expense], profile: nil, interval: interval)
            #expect(entries.count == 1)
            #expect(entries.first?.amount == 1000)
        }
    }

}
