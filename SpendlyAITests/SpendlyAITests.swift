//
//  SpendlyAITests.swift
//  SpendlyAITests
//

import Foundation
import Testing
@testable import SpendlyAI

struct SpendlyAITests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func calculatesDailyBudgetAfterReservations() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let nextIncome = date(year: 2026, month: 9, day: 21)
        let input = BudgetInput(
            availableMoney: 10_000,
            periodStart: today,
            nextIncomeDate: nextIncome,
            fixedExpenses: [
                BudgetFixedExpense(amount: 2_000, dueDay: 15),
                BudgetFixedExpense(amount: 900, dueDay: 25)
            ],
            savingsGoals: [
                BudgetSavingsGoal(targetAmount: 2_000, savedAmount: 500, targetDate: date(year: 2026, month: 9, day: 20))
            ],
            minimumBuffer: 1_000
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.availableUntilNextIncome == 10_000)
        #expect(result.upcomingFixedExpenses == 2_000)
        #expect(result.plannedSavings == 1_500)
        #expect(result.minimumBuffer == 1_000)
        #expect(result.disposableAmount == 5_500)
        #expect(result.daysRemaining == 10)
        #expect(result.recommendedDailyMaximum == 550)
        #expect(result.remainingSafeAmountToday == 550)
        #expect(result.isNegativeBudget == false)
    }

    @Test func updatesRemainingSafeAmountAfterTodaysPurchases() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 1_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 16),
            transactions: [
                BudgetTransaction(amount: 120, date: today),
                BudgetTransaction(amount: 80, date: date(year: 2026, month: 9, day: 10))
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.recommendedDailyMaximum == 200)
        #expect(result.spentToday == 120)
        #expect(result.remainingSafeAmountToday == 80)
    }

    @Test func handlesNegativeBudget() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 1_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 21),
            fixedExpenses: [BudgetFixedExpense(amount: 1_200, dueDay: 12)],
            minimumBuffer: 300
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.disposableAmount == -500)
        #expect(result.recommendedDailyMaximum == -50)
        #expect(result.isNegativeBudget)
    }

    @Test func ignoresInactiveExpensesAndFutureSavingsGoals() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let nextIncome = date(year: 2026, month: 9, day: 21)
        let input = BudgetInput(
            availableMoney: 4_000,
            periodStart: today,
            nextIncomeDate: nextIncome,
            fixedExpenses: [BudgetFixedExpense(amount: 900, dueDay: 12, isActive: false)],
            savingsGoals: [BudgetSavingsGoal(targetAmount: 3_000, savedAmount: 0, targetDate: date(year: 2026, month: 10, day: 1))]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 0)
        #expect(result.plannedSavings == 0)
        #expect(result.disposableAmount == 4_000)
    }

    @Test func findsUpcomingExpenseAcrossMonthBoundary() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 29)
        let input = BudgetInput(
            availableMoney: 2_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 10, day: 5),
            fixedExpenses: [BudgetFixedExpense(amount: 700, dueDay: 2)]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 700)
        #expect(result.disposableAmount == 1_300)
    }

    @Test func usesAtLeastOneDayForSameDayIncome() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 300,
            periodStart: today,
            nextIncomeDate: today
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.daysRemaining == 1)
        #expect(result.recommendedDailyMaximum == 300)
    }

    @Test @MainActor func aiServiceReportsMissingAccessWithoutBackend() async {
        let service = AIService()
        let request = AIRequest(
            question: "Can I spend more today?",
            budgetContext: aiBudgetContext(isBudgetUnderPressure: false)
        )

        let result = await service.answer(request)

        #expect(result == .failure(.missingAccess))
    }

    @Test func aiServiceReturnsLocalFallbackWhenBudgetIsPressured() {
        let service = AIService()
        let request = AIRequest(
            question: "Can I spend more today?",
            budgetContext: aiBudgetContext(isBudgetUnderPressure: true)
        )

        let response = service.fallbackAnswer(for: request, after: .missingAccess)

        #expect(response.message == "ai.fallback.pressured")
    }

    @Test func aiBudgetContextContainsSummaryInsteadOfTransactionHistory() {
        let context = aiBudgetContext(isBudgetUnderPressure: false)

        #expect(context.currencyCode == "NOK")
        #expect(context.safeToSpendToday == 250)
        #expect(context.spentToday == 50)
        #expect(context.remainingToday == 200)
        #expect(context.daysUntilNextIncome == 8)
    }

    @Test func dailyInsightUsesActualBudgetValues() {
        let service = DailyInsightService(locale: Locale(identifier: "en_US_POSIX"))
        let context = aiBudgetContext(isBudgetUnderPressure: false)

        let insight = service.makeInsight(from: context)

        #expect(insight.message.contains("NOK"))
        #expect(insight.message.contains("250"))
        #expect(insight.message.contains("188"))
    }

    @Test func dailyInsightStaysShortAndNonMoralizing() {
        let service = DailyInsightService(locale: Locale(identifier: "en_US_POSIX"))
        let insight = service.makeInsight(from: aiBudgetContext(isBudgetUnderPressure: true))
        let lowercasedMessage = insight.message.lowercased()
        let blockedWords = ["shame", "guilt", "bad", "irresponsible", "coffee", "restaurant"]

        #expect(sentenceCount(in: insight.message) <= 3)
        #expect(blockedWords.allSatisfy { !lowercasedMessage.contains($0) })
    }

    @Test func dailyReminderDefaultsToEightInTheMorning() {
        #expect(NotificationSettingsStorage.defaultReminderHour == 8)
        #expect(NotificationSettingsStorage.defaultReminderMinute == 0)
    }

    @Test func dailyReminderHidesBudgetDetailsByDefault() {
        let service = NotificationService()
        let content = service.makeDailyReminderContent(
            context: aiBudgetContext(isBudgetUnderPressure: false),
            includeBudgetDetails: false,
            locale: Locale(identifier: "en_US_POSIX")
        )

        #expect(!content.body.contains("NOK"))
        #expect(!content.body.contains("200"))
    }

    @Test func dailyReminderCanIncludeUpdatedBudgetAmountWhenEnabled() {
        let service = NotificationService()
        let content = service.makeDailyReminderContent(
            context: aiBudgetContext(isBudgetUnderPressure: false),
            includeBudgetDetails: true,
            locale: Locale(identifier: "en_US_POSIX")
        )

        #expect(content.body.contains("NOK"))
        #expect(content.body.contains("200"))
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }

    private func aiBudgetContext(isBudgetUnderPressure: Bool) -> AIBudgetContext {
        AIBudgetContext(
            currencyCode: "NOK",
            safeToSpendToday: 250,
            spentToday: 50,
            remainingToday: 200,
            daysUntilNextIncome: 8,
            upcomingFixedExpenses: 1_200,
            plannedSavings: 500,
            minimumBuffer: 1_000,
            isBudgetUnderPressure: isBudgetUnderPressure
        )
    }

    private func sentenceCount(in message: String) -> Int {
        message
            .split { ".!?".contains($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
}
