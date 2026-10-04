//
//  SpendlyAITests.swift
//  SpendlyAITests
//

import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import SpendlyAI

struct SpendlyAITests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func keepsGamblingSeparateFromEntertainment() {
        #expect(SpendingCategory.gambling != .entertainment)
        #expect(SpendingCategory.gambling.rawValue == "gambling")
        #expect(SpendingCategory.allCases.contains(.gambling))
        #expect(ExpenseCategory.allCases.contains(.gambling))
    }

    @Test func marksOnlyPendingPastDuePaymentsAsOverdue() {
        let now = date(year: 2026, month: 10, day: 4)
        let yesterday = date(year: 2026, month: 10, day: 3)
        let tomorrow = date(year: 2026, month: 10, day: 5)

        #expect(PaymentStatus.pending.effectiveStatus(dueDate: tomorrow, now: now, calendar: calendar) == .pending)
        #expect(PaymentStatus.pending.effectiveStatus(dueDate: yesterday, now: now, calendar: calendar) == .overdue)
        #expect(PaymentStatus.settled.effectiveStatus(dueDate: yesterday, now: now, calendar: calendar) == .settled)
        #expect(PaymentStatus.withdrawn.effectiveStatus(dueDate: yesterday, now: now, calendar: calendar) == .withdrawn)
    }

    @Test func formatsNorwegianCurrencyWithTwoDecimals() {
        let locale = Locale(identifier: "nb_NO")

        let formatted = (Decimal(18_125) / Decimal(10)).formatted(
            .currency(code: "NOK")
                .precision(.fractionLength(2))
                .locale(locale)
        )

        #expect(formatted.contains("1 812,50"))
        #expect(formatted.contains("kr"))
    }

    @Test func parsesMoneyWithCommaOrPointAsDecimalSeparator() {
        #expect(MoneyParser.decimal(from: "1812,50") == Decimal(string: "1812.50"))
        #expect(MoneyParser.decimal(from: "1812.50") == Decimal(string: "1812.50"))
        #expect(MoneyParser.decimal(from: "1 812,50") == Decimal(string: "1812.50"))
        #expect(MoneyParser.decimal(from: "1.812,50") == Decimal(string: "1812.50"))
        #expect(MoneyParser.decimal(from: "1,812.50") == Decimal(string: "1812.50"))
        #expect(MoneyParser.decimal(from: "not money") == nil)
    }

    @Test func formatsMoneyUsingCommercialRounding() throws {
        let locale = Locale(identifier: "nb_NO")
        let amount = try #require(MoneyParser.decimal(from: "12.345"))

        #expect(
            MoneyFormatter.string(
                from: amount,
                currencyCode: "NOK",
                locale: locale
            ).contains("12,35")
        )
    }

    @Test func formatsZeroNegativeAndLargeMoneyAmounts() throws {
        let locale = Locale(identifier: "nb_NO")
        let negativeAmount = try #require(Decimal(string: "-1234.565"))
        let largeAmount = try #require(Decimal(string: "1234567.89"))
        let normalized: (Decimal) -> String = { amount in
            MoneyFormatter.string(
                from: amount,
                currencyCode: "NOK",
                locale: locale
            )
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        }

        #expect(normalized(0).contains("0,00"))
        #expect(normalized(negativeAmount).contains("−1 234,57"))
        #expect(normalized(largeAmount).contains("1 234 567,89"))
    }

    @Test func formatsSupportedCurrenciesConsistently() throws {
        let amount = try #require(Decimal(string: "1234.5"))
        let cases = [
            ("NOK", Locale(identifier: "nb_NO"), "1 234,50", "kr"),
            ("USD", Locale(identifier: "en_US"), "1,234.50", "$"),
            ("THB", Locale(identifier: "th_TH"), "1,234.50", "฿")
        ]

        for (currencyCode, locale, expectedAmount, expectedCurrencySymbol) in cases {
            let formatted = MoneyFormatter.string(
                from: amount,
                currencyCode: currencyCode,
                locale: locale
            )
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")

            #expect(formatted.contains(expectedAmount))
            #expect(formatted.contains(expectedCurrencySymbol))
        }
    }

    @Test func keepsDecimalPrecisionThroughoutMoneyCalculations() throws {
        let tenCents = try #require(Decimal(string: "0.10"))
        let twentyCents = try #require(Decimal(string: "0.20"))
        let expectedSum = try #require(Decimal(string: "0.30"))
        let largeAmount = try #require(Decimal(string: "1234567.89"))
        let expectedRemainder = try #require(Decimal(string: "1234567.59"))

        #expect(tenCents + twentyCents == expectedSum)
        #expect(largeAmount - expectedSum == expectedRemainder)
    }

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

    @Test func countsWeeklyExpensesUntilNextIncome() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 10, day: 1)
        let input = BudgetInput(
            availableMoney: 2_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 10, day: 23),
            fixedExpenses: [
                BudgetFixedExpense(
                    amount: 100,
                    dueDay: 3,
                    recurrence: .weekly
                )
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 300)
        #expect(result.disposableAmount == 1_700)
    }

    @Test func countsBiweeklyExpensesAcrossMonthBoundary() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 10, day: 25)
        let input = BudgetInput(
            availableMoney: 2_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 11, day: 30),
            fixedExpenses: [
                BudgetFixedExpense(
                    amount: 150,
                    dueDay: 28,
                    recurrence: .biweekly
                )
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 450)
    }

    @Test func countsQuarterlyExpensesAcrossYearBoundary() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 12, day: 20)
        let input = BudgetInput(
            availableMoney: 4_000,
            periodStart: today,
            nextIncomeDate: date(year: 2027, month: 4, day: 5),
            fixedExpenses: [
                BudgetFixedExpense(
                    amount: 500,
                    dueDay: 28,
                    recurrence: .quarterly
                )
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 1_000)
    }

    @Test func countsYearlyExpensesAcrossMultipleYears() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 12, day: 20)
        let input = BudgetInput(
            availableMoney: 4_000,
            periodStart: today,
            nextIncomeDate: date(year: 2028, month: 1, day: 5),
            fixedExpenses: [
                BudgetFixedExpense(
                    amount: 600,
                    dueDay: 28,
                    recurrence: .yearly
                )
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 1_200)
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

    @Test func handlesVeryLowIncome() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 90,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 20)
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.disposableAmount == 90)
        #expect(result.daysRemaining == 9)
        #expect(result.recommendedDailyMaximum == 10)
        #expect(result.remainingSafeAmountToday == 10)
    }

    @Test func handlesExpensesGreaterThanIncome() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 1_500,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 21),
            fixedExpenses: [
                BudgetFixedExpense(amount: 1_400, dueDay: 12),
                BudgetFixedExpense(amount: 700, dueDay: 15)
            ]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 2_100)
        #expect(result.disposableAmount == -600)
        #expect(result.recommendedDailyMaximum == -60)
        #expect(result.isNegativeBudget)
    }

    @Test func handlesZeroAvailableMoney() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 0,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 16)
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.disposableAmount == 0)
        #expect(result.recommendedDailyMaximum == 0)
        #expect(result.remainingSafeAmountToday == 0)
        #expect(result.isNegativeBudget == false)
    }

    @Test func includesFixedExpensesDueOnPayday() {
        let service = BudgetService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 11)
        let input = BudgetInput(
            availableMoney: 1_000,
            periodStart: today,
            nextIncomeDate: date(year: 2026, month: 9, day: 15),
            fixedExpenses: [BudgetFixedExpense(amount: 250, dueDay: 15)]
        )

        let result = service.calculateBudget(for: input, today: today)

        #expect(result.upcomingFixedExpenses == 250)
        #expect(result.disposableAmount == 750)
        #expect(result.daysRemaining == 4)
    }

    @Test func realizedRecurringIncomeIncreasesAvailableMoney() {
        let service = BudgetService(calendar: calendar)
        let periodStart = date(year: 2026, month: 10, day: 1)
        let today = date(year: 2026, month: 10, day: 15)
        let profile = UserFinancialProfile(
            monthlyNetIncome: 30_000,
            paydayDay: 1,
            budgetPeriodStart: periodStart,
            budgetPeriodEnd: date(year: 2026, month: 11, day: 1)
        )
        let freelanceIncome = Income(
            amount: 1_000,
            date: periodStart,
            category: .freelance,
            recurrence: .weekly
        )
        let midPeriodIncome = Income(
            amount: 500,
            date: date(year: 2026, month: 10, day: 10),
            category: .gift
        )

        let input = service.makeInput(
            profile: profile,
            fixedExpenses: [],
            savingsGoals: [],
            transactions: [],
            incomes: [freelanceIncome, midPeriodIncome],
            today: today
        )

        #expect(input.availableMoney == 33_500)
    }

    @Test func salaryIncomeDoesNotDoubleCountProfileSalary() {
        let service = BudgetService(calendar: calendar)
        let periodStart = date(year: 2026, month: 10, day: 1)
        let profile = UserFinancialProfile(
            monthlyNetIncome: 30_000,
            paydayDay: 1,
            budgetPeriodStart: periodStart,
            budgetPeriodEnd: date(year: 2026, month: 11, day: 1)
        )
        let registeredSalary = Income(
            amount: 30_000,
            date: periodStart,
            category: .salary,
            recurrence: .monthly
        )

        let input = service.makeInput(
            profile: profile,
            fixedExpenses: [],
            savingsGoals: [],
            transactions: [],
            incomes: [registeredSalary],
            today: date(year: 2026, month: 10, day: 15)
        )

        #expect(input.availableMoney == 30_000)
    }

    @Test func incomeLaterOnBudgetEndDateIsIncluded() {
        let service = BudgetService(calendar: calendar)
        let endDate = date(year: 2026, month: 10, day: 4)
        let incomeTime = calendar.date(byAdding: .hour, value: 12, to: endDate)!
        let profile = UserFinancialProfile(
            monthlyNetIncome: 45_000,
            paydayDay: 4,
            budgetPeriodStart: date(year: 2026, month: 9, day: 4),
            budgetPeriodEnd: endDate
        )
        let income = Income(
            amount: 1_000,
            date: incomeTime,
            category: .freelance,
            recurrence: .weekly
        )

        let input = service.makeInput(
            profile: profile,
            fixedExpenses: [],
            savingsGoals: [],
            transactions: [],
            incomes: [income],
            today: incomeTime
        )

        #expect(input.availableMoney == 46_000)
    }

    @Test func futureAndInactiveIncomeDoNotAffectCurrentBudget() {
        let service = BudgetService(calendar: calendar)
        let periodStart = date(year: 2026, month: 10, day: 1)
        let profile = UserFinancialProfile(
            monthlyNetIncome: 30_000,
            paydayDay: 1,
            budgetPeriodStart: periodStart,
            budgetPeriodEnd: date(year: 2026, month: 11, day: 1)
        )
        let futureIncome = Income(
            amount: 5_000,
            date: date(year: 2026, month: 10, day: 20),
            category: .other
        )
        let inactiveIncome = Income(
            amount: 2_000,
            date: periodStart,
            category: .freelance,
            recurrence: .weekly,
            isActive: false
        )

        let input = service.makeInput(
            profile: profile,
            fixedExpenses: [],
            savingsGoals: [],
            transactions: [],
            incomes: [futureIncome, inactiveIncome],
            today: date(year: 2026, month: 10, day: 15)
        )

        #expect(input.availableMoney == 30_000)
    }

    @Test func dailyInsightFormatsDifferentCurrencies() {
        let service = DailyInsightService(locale: Locale(identifier: "en_US_POSIX"))
        let usdInsight = service.makeInsight(from: aiBudgetContext(currencyCode: "USD", isBudgetUnderPressure: false))
        let thbInsight = service.makeInsight(from: aiBudgetContext(currencyCode: "THB", isBudgetUnderPressure: false))

        #expect(usdInsight.message.contains("$"))
        #expect(thbInsight.message.contains("THB"))
        #expect(usdInsight.message != thbInsight.message)
    }

    @Test func appAppearanceSupportsSystemLightAndDark() {
        #expect(AppAppearance.allCases == [.system, .light, .dark])
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func localizationCatalogContainsEnglishNorwegianAndThai() {
        let localizations = Set(Bundle.main.localizations)

        #expect(localizations.contains("en"))
        #expect(localizations.contains("nb"))
        #expect(localizations.contains("th"))
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

    @Test @MainActor func aiServiceReportsNetworkUnavailableWithoutInternet() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = AIService(
            backendURL: URL(string: "https://example.invalid/spendly-ai")!,
            urlSession: session
        )
        let request = AIRequest(
            question: "Can I spend more today?",
            budgetContext: aiBudgetContext(isBudgetUnderPressure: false)
        )

        let result = await service.answer(request)

        #expect(result == .failure(.networkUnavailable))
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

    @Test func aiRequestEncodingDoesNotIncludeTransactionHistoryFields() throws {
        let request = AIRequest(
            question: "How much can I spend?",
            budgetContext: aiBudgetContext(isBudgetUnderPressure: false)
        )

        let data = try JSONEncoder().encode(request)
        let payload = String(decoding: data, as: UTF8.self)

        #expect(!payload.contains("transactions"))
        #expect(!payload.contains("transactionDescription"))
        #expect(!payload.contains("notes"))
        #expect(!payload.contains("isEssential"))
        #expect(!payload.contains("bank"))
    }

    @Test func dailyInsightUsesActualBudgetValues() {
        let service = DailyInsightService(locale: Locale(identifier: "en_US_POSIX"))
        let context = aiBudgetContext(isBudgetUnderPressure: false)

        let insight = service.makeInsight(from: context)

        #expect(insight.message.contains("NOK"))
        #expect(insight.message.contains("250"))
        #expect(insight.message.contains("187.50"))
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

    @Test func goalPlanCalculatesWeeklyAndMonthlySavingsNeeded() {
        let service = GoalPlanningService(calendar: calendar)
        let today = date(year: 2026, month: 9, day: 1)
        let targetDate = date(year: 2026, month: 9, day: 29)

        let plan = service.plan(
            targetAmount: 4_000,
            savedAmount: 1_200,
            targetDate: targetDate,
            today: today
        )

        #expect(plan.remainingAmount == 2_800)
        #expect(plan.weeklySavingsNeeded == 700)
        #expect(plan.monthlySavingsNeeded == 2_800)
        #expect(plan.daysRemaining == 28)
        #expect(plan.progress == 0.3)
        #expect(!plan.isCompleted)
    }

    @Test func goalPlanMarksFullySavedGoalCompleted() {
        let service = GoalPlanningService(calendar: calendar)

        let plan = service.plan(
            targetAmount: 2_000,
            savedAmount: 2_100,
            targetDate: date(year: 2026, month: 10, day: 1),
            today: date(year: 2026, month: 9, day: 1)
        )

        #expect(plan.remainingAmount == 0)
        #expect(plan.weeklySavingsNeeded == 0)
        #expect(plan.monthlySavingsNeeded == 0)
        #expect(plan.progress == 1)
        #expect(plan.isCompleted)
    }

    @Test func plusProductConfigurationUsesStableStoreKitIdentifier() {
        #expect(PurchaseConfiguration.plusMonthlyProductID == "spendlyai.plus.monthly")
        #expect(PurchaseConfiguration.plusProductIDs == ["spendlyai.plus.monthly"])
    }

    @Test func purchaseStateKeepsUnavailableSeparateFromFree() {
        #expect(PurchaseState.unavailable != .notPurchased)
        #expect(PurchaseState.purchased != .notPurchased)
    }

    @Test func cloudSyncReadinessKeepsMVPUnblocked() {
        let report = CloudSyncReadinessService().makeReport()

        #expect(report.decision == .localFirstMVP)
        #expect(report.shouldBlockMVP == false)
    }

    @Test func cloudSyncReadinessTracksRequiredValidationBeforeEnablingSync() {
        let report = CloudSyncReadinessService().makeReport()

        #expect(report.pendingRequirements.contains(.iCloudCapability))
        #expect(report.pendingRequirements.contains(.backgroundRemoteNotifications))
        #expect(report.pendingRequirements.contains(.cloudKitCompatibleSchema))
        #expect(report.pendingRequirements.contains(.multiDeviceValidation))
        #expect(report.pendingRequirements.contains(.conflictValidation))
        #expect(report.pendingRequirements.contains(.offlineOnlineValidation))
        #expect(report.pendingRequirements.contains(.reinstallValidation))
    }

    @Test func backupRoundTripPreservesAllSupportedData() throws {
        let service = BackupService()
        let createdAt = date(year: 2026, month: 10, day: 4)
        let profile = UserFinancialProfile(
            monthlyNetIncome: 30_000.50,
            paydayDay: 19,
            budgetPeriodStart: createdAt,
            budgetPeriodEnd: date(year: 2026, month: 11, day: 19),
            currencyCode: "NOK",
            minimumBuffer: 1_500.25,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let transaction = Transaction(
            amount: 123.45,
            date: createdAt,
            category: .groceries,
            transactionDescription: "Mat",
            isEssential: true,
            notes: "Ukentlig",
            dueDate: date(year: 2026, month: 10, day: 8),
            settledDate: createdAt,
            paymentStatus: .withdrawn
        )
        let income = Income(
            amount: 30_000.75,
            date: createdAt,
            category: .salary,
            incomeDescription: "Lønn",
            notes: "Oktober",
            recurrence: .monthly,
            isActive: false,
            dueDate: date(year: 2026, month: 10, day: 19),
            settledDate: createdAt,
            paymentStatus: .settled
        )
        let fixedExpense = FixedExpense(
            name: "Husleie",
            amount: 12_000.75,
            dueDay: 1,
            category: .housing,
            recurrence: .monthly,
            dueDate: date(year: 2026, month: 10, day: 1),
            settledDate: createdAt,
            paymentStatus: .settled
        )
        let goal = SavingsGoal(
            name: "Buffer",
            targetAmount: 50_000.50,
            targetDate: date(year: 2027, month: 1, day: 1),
            savedAmount: 2_000.25,
            priority: .high
        )

        let original = service.makeBackup(
            profile: profile,
            transactions: [transaction],
            incomes: [income],
            fixedExpenses: [fixedExpense],
            savingsGoals: [goal],
            createdAt: createdAt
        )
        let decoded = try service.decodeAndValidate(service.encode(original))

        #expect(decoded == original)
        #expect(decoded.formatVersion == SpendlyBackup.currentFormatVersion)
        #expect(decoded.summary.profileCount == 1)
        #expect(decoded.summary.transactionCount == 1)
        #expect(decoded.summary.incomeCount == 1)
        #expect(decoded.incomes.first?.recurrence == .monthly)
        #expect(decoded.incomes.first?.isActive == false)
        #expect(decoded.transactions.first?.paymentStatus == .withdrawn)
        #expect(decoded.transactions.first?.settledDate == createdAt)
        #expect(decoded.incomes.first?.paymentStatus == .settled)
        #expect(decoded.fixedExpenses.first?.dueDate == date(year: 2026, month: 10, day: 1))
        #expect(decoded.summary.fixedExpenseCount == 1)
        #expect(decoded.summary.savingsGoalCount == 1)
    }

    @Test func backupAcceptsRepresentableLegacyValues() throws {
        let service = BackupService()
        let laterDate = date(year: 2026, month: 10, day: 20)
        let earlierDate = date(year: 2026, month: 10, day: 1)
        let backup = service.makeBackup(
            profile: UserFinancialProfile(
                monthlyNetIncome: 30_000,
                paydayDay: 19,
                budgetPeriodStart: laterDate,
                budgetPeriodEnd: earlierDate
            ),
            transactions: [],
            fixedExpenses: [FixedExpense(name: "", amount: 100, dueDay: 1)],
            savingsGoals: [SavingsGoal(name: "", targetAmount: 1_000, targetDate: laterDate)]
        )

        let decoded = try service.decodeAndValidate(service.encode(backup))

        #expect(decoded.profile?.budgetPeriodStart == laterDate)
        #expect(decoded.profile?.budgetPeriodEnd == earlierDate)
        #expect(decoded.fixedExpenses.first?.name == "")
        #expect(decoded.savingsGoals.first?.name == "")
    }

    @Test func invalidBackupIsRejectedBeforeRestore() throws {
        let service = BackupService()
        let invalidData = Data(#"{"formatVersion":1,"createdAt":"not-a-date"}"#.utf8)

        #expect(throws: BackupError.unreadableFile) {
            try service.decodeAndValidate(invalidData)
        }
    }

    @Test func unsupportedBackupVersionIsRejected() throws {
        let service = BackupService()
        let current = service.makeBackup(
            profile: nil,
            transactions: [],
            fixedExpenses: [],
            savingsGoals: []
        )
        let data = try service.encode(SpendlyBackup(
            formatVersion: 999,
            createdAt: current.createdAt,
            profile: nil,
            transactions: [],
            fixedExpenses: [],
            savingsGoals: []
        ))

        #expect(throws: BackupError.unsupportedVersion(999)) {
            try service.decodeAndValidate(data)
        }
    }

    @Test @MainActor func restoreWorksWithAnEmptyStore() throws {
        let schema = Schema([
            UserFinancialProfile.self,
            SpendlyAI.Transaction.self,
            Income.self,
            FixedExpense.self,
            SavingsGoal.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let service = BackupService()
        let backup = service.makeBackup(
            profile: UserFinancialProfile(monthlyNetIncome: 10_000, paydayDay: 1),
            transactions: [],
            fixedExpenses: [],
            savingsGoals: []
        )

        try service.restore(backup, in: context)

        #expect(try context.fetchCount(FetchDescriptor<UserFinancialProfile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SpendlyAI.Transaction>()) == 0)
    }

    @Test @MainActor func restoreReplacesAllSupportedData() throws {
        let schema = Schema([
            UserFinancialProfile.self,
            Transaction.self,
            Income.self,
            FixedExpense.self,
            SavingsGoal.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        context.insert(Transaction(amount: 999, transactionDescription: "Old"))
        context.insert(Income(amount: 999, incomeDescription: "Old income"))
        try context.save()

        let service = BackupService()
        let createdAt = date(year: 2026, month: 10, day: 4)
        let backup = service.makeBackup(
            profile: UserFinancialProfile(monthlyNetIncome: 20_000, paydayDay: 15),
            transactions: [Transaction(amount: 42.50, date: createdAt, transactionDescription: "New")],
            incomes: [Income(amount: 1_500.25, date: createdAt, category: .freelance, incomeDescription: "New income")],
            fixedExpenses: [FixedExpense(name: "Rent", amount: 8_000, dueDay: 1)],
            savingsGoals: [SavingsGoal(name: "Trip", targetAmount: 5_000, targetDate: createdAt)]
        )

        try service.restore(backup, in: context)

        let restoredProfiles = try context.fetch(FetchDescriptor<UserFinancialProfile>())
        let restoredTransactions = try context.fetch(FetchDescriptor<SpendlyAI.Transaction>())
        let restoredIncomes = try context.fetch(FetchDescriptor<Income>())
        let restoredExpenses = try context.fetch(FetchDescriptor<FixedExpense>())
        let restoredGoals = try context.fetch(FetchDescriptor<SavingsGoal>())

        #expect(restoredProfiles.count == 1)
        #expect(restoredTransactions.count == 1)
        #expect(restoredTransactions.first?.transactionDescription == "New")
        #expect(restoredTransactions.first?.amount == 42.50)
        #expect(restoredIncomes.count == 1)
        #expect(restoredIncomes.first?.incomeDescription == "New income")
        #expect(restoredIncomes.first?.amount == 1_500.25)
        #expect(restoredExpenses.count == 1)
        #expect(restoredGoals.count == 1)
    }

    @Test func reportSummaryUsesOnlyEntriesInsideSelectedPeriod() {
        let service = ReportSummaryService()
        let periodStart = date(year: 2026, month: 10, day: 1)
        let periodEnd = date(year: 2026, month: 10, day: 31)
        let transactions = [
            Transaction(amount: 100.25, date: date(year: 2026, month: 10, day: 1)),
            Transaction(amount: 20.50, date: date(year: 2026, month: 10, day: 31)),
            Transaction(amount: 999, date: date(year: 2026, month: 11, day: 1))
        ]
        let incomes = [
            Income(amount: 1_000.75, date: date(year: 2026, month: 10, day: 15)),
            Income(amount: 500, date: date(year: 2026, month: 9, day: 30))
        ]

        let summary = service.makeSummary(
            transactions: transactions,
            incomes: incomes,
            startDate: periodStart,
            endDate: periodEnd,
            calendar: calendar
        )

        #expect(summary.totalIncome == Decimal(string: "1000.75"))
        #expect(summary.totalVariableExpenses == Decimal(string: "120.75"))
        #expect(summary.netResult == Decimal(string: "880.00"))
        #expect(summary.entryCount == 3)
    }

    @Test func reportSummaryKeepsGamblingAsItsOwnCategory() {
        let service = ReportSummaryService()
        let reportDate = date(year: 2026, month: 10, day: 4)
        let transactions = [
            Transaction(amount: 25, date: reportDate, category: .gambling),
            Transaction(amount: 5, date: reportDate, category: .gambling),
            Transaction(amount: 10, date: reportDate, category: .entertainment)
        ]
        let fixedExpense = FixedExpense(
            name: "Lottery",
            amount: 100,
            dueDay: 4,
            category: .gambling,
            recurrence: .monthly
        )

        let summary = service.makeSummary(
            transactions: transactions,
            incomes: [],
            fixedExpenses: [fixedExpense],
            startDate: date(year: 2026, month: 10, day: 1),
            endDate: date(year: 2026, month: 10, day: 31),
            calendar: calendar
        )

        #expect(summary.variableExpenseCategories.first { $0.category == .gambling }?.amount == 30)
        #expect(summary.variableExpenseCategories.first { $0.category == .entertainment }?.amount == 10)
        #expect(summary.fixedExpenseCategories.first { $0.category == .gambling }?.amount == 100)
    }

    @Test func reportSummaryIncludesRecurringFixedExpensesAndPlannedSavings() {
        let service = ReportSummaryService()
        let fixedExpense = FixedExpense(
            name: "Husleie",
            amount: 10_000,
            dueDay: 4,
            recurrence: .monthly
        )
        let goal = SavingsGoal(
            name: "Ferie",
            targetAmount: 5_000,
            targetDate: date(year: 2026, month: 10, day: 20),
            savedAmount: 1_500
        )

        let summary = service.makeSummary(
            transactions: [],
            incomes: [Income(amount: 20_000, date: date(year: 2026, month: 10, day: 1))],
            fixedExpenses: [fixedExpense],
            savingsGoals: [goal],
            startDate: date(year: 2026, month: 10, day: 1),
            endDate: date(year: 2026, month: 10, day: 31),
            calendar: calendar
        )

        #expect(summary.totalFixedExpenses == 10_000)
        #expect(summary.plannedSavings == 3_500)
        #expect(summary.netResult == 6_500)
        #expect(summary.entryCount == 3)
    }

    @Test @MainActor func reportPDFGeneratorCreatesReadablePDFDocument() throws {
        let summary = ReportSummary(
            totalIncome: 30_000,
            totalVariableExpenses: 1_250.50,
            totalFixedExpenses: 10_000,
            plannedSavings: 2_000,
            entryCount: 4,
            variableExpenseCategories: [
                ReportSpendingCategoryTotal(category: .transport, amount: 1_250.50)
            ],
            fixedExpenseCategories: [
                ReportFixedExpenseCategoryTotal(category: .housing, amount: 10_000)
            ]
        )
        let request = ReportPDFRequest(
            appName: "SpendlyAI",
            startDate: date(year: 2026, month: 10, day: 1),
            endDate: date(year: 2026, month: 10, day: 31),
            currencyCode: "NOK",
            generatedAt: date(year: 2026, month: 11, day: 1),
            summary: summary
        )

        let data = ReportPDFGenerator().makePDF(
            for: request,
            locale: Locale(identifier: "nb_NO")
        )
        let dataProvider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(dataProvider))

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(document.numberOfPages == 1)
    }

    @Test @MainActor func reportPDFGeneratorAddsPagesForLargeCategoryLists() throws {
        let categoryRows = Array(
            repeating: ReportSpendingCategoryTotal(category: .other, amount: 10),
            count: 80
        )
        let summary = ReportSummary(
            totalIncome: 0,
            totalVariableExpenses: 800,
            totalFixedExpenses: 0,
            plannedSavings: 0,
            entryCount: 80,
            variableExpenseCategories: categoryRows,
            fixedExpenseCategories: []
        )
        let request = ReportPDFRequest(
            appName: "SpendlyAI",
            startDate: date(year: 2026, month: 1, day: 1),
            endDate: date(year: 2026, month: 12, day: 31),
            currencyCode: "NOK",
            generatedAt: date(year: 2027, month: 1, day: 1),
            summary: summary
        )

        let data = ReportPDFGenerator().makePDF(for: request)
        let dataProvider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(dataProvider))

        #expect(document.numberOfPages > 1)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }

    private func aiBudgetContext(currencyCode: String = "NOK", isBudgetUnderPressure: Bool) -> AIBudgetContext {
        AIBudgetContext(
            currencyCode: currencyCode,
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

private final class OfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
