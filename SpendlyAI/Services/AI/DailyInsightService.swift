//
//  DailyInsightService.swift
//  SpendlyAI
//

import Foundation

struct DailyInsight: Equatable {
    let message: String

    init(message: String) {
        self.message = message
    }
}

struct DailyInsightService {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func makeInsight(from context: AIBudgetContext) -> DailyInsight {
        let safeAmount = formattedCurrency(context.safeToSpendToday, currencyCode: context.currencyCode)
        let remainingAmount = formattedCurrency(max(context.remainingToday, 0), currencyCode: context.currencyCode)
        let flexibleTarget = max(context.safeToSpendToday * Decimal(0.75), 0)
        let flexibleTargetAmount = formattedCurrency(flexibleTarget, currencyCode: context.currencyCode)
        let extraRoomAmount = formattedCurrency(max(context.safeToSpendToday - flexibleTarget, 0), currencyCode: context.currencyCode)

        if context.isBudgetUnderPressure || context.safeToSpendToday < 0 {
            return DailyInsight(message: String(
                format: String(localized: "dailyInsight.pressured"),
                remainingAmount
            ))
        }

        if context.remainingToday < 0 {
            return DailyInsight(message: String(
                format: String(localized: "dailyInsight.overDailyAmount"),
                safeAmount
            ))
        }

        if context.remainingToday <= context.safeToSpendToday * Decimal(0.25) {
            return DailyInsight(message: String(
                format: String(localized: "dailyInsight.lowRemaining"),
                remainingAmount
            ))
        }

        if context.daysUntilNextIncome <= 3 {
            return DailyInsight(message: String(
                format: String(localized: "dailyInsight.nearIncome"),
                safeAmount,
                context.daysUntilNextIncome
            ))
        }

        return DailyInsight(message: String(
            format: String(localized: "dailyInsight.flexible"),
            safeAmount,
            flexibleTargetAmount,
            extraRoomAmount
        ))
    }

    private func formattedCurrency(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? amount.description
    }
}
