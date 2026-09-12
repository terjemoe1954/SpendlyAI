//
//  UserFinancialProfile.swift
//  SpendlyAI
//

import Foundation
import SwiftData

@Model
final class UserFinancialProfile {
    var monthlyNetIncome: Decimal
    var paydayDay: Int
    var budgetPeriodStart: Date
    var budgetPeriodEnd: Date
    var currencyCode: String
    var minimumBuffer: Decimal
    var createdAt: Date
    var updatedAt: Date

    init(
        monthlyNetIncome: Decimal = 0,
        paydayDay: Int = 1,
        budgetPeriodStart: Date = .now,
        budgetPeriodEnd: Date = .now,
        currencyCode: String = "NOK",
        minimumBuffer: Decimal = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.monthlyNetIncome = monthlyNetIncome
        self.paydayDay = paydayDay
        self.budgetPeriodStart = budgetPeriodStart
        self.budgetPeriodEnd = budgetPeriodEnd
        self.currencyCode = currencyCode
        self.minimumBuffer = minimumBuffer
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
