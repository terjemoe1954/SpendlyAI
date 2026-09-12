//
//  SpendlyAITests.swift
//  SpendlyAITests
//

import Foundation
import SwiftUI
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

    @Test func localizationCatalogContainsEnglishNorwegianAndThai() throws {
        let catalog = try localizationCatalog()
        let strings = try #require(catalog["strings"] as? [String: Any])
        let requiredKeys = [
            "tab.home",
            "tab.transactions",
            "tab.ai",
            "tab.goals",
            "tab.settings",
            "dashboard.safeToSpend.title",
            "transaction.new.title",
            "ai.ask",
            "goal.add",
            "settings.appName",
            "settings.profile"
        ]

        for key in requiredKeys {
            let entry = try #require(strings[key] as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])

            #expect(localizations["en"] != nil)
            #expect(localizations["nb"] != nil)
            #expect(localizations["th"] != nil)
        }
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

    private func localizationCatalog() throws -> [String: Any] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let catalogURL = projectRootURL.appendingPathComponent("SpendlyAI/Localization/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)

        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
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
