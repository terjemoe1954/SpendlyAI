//
//  DailyBudgetSnapshot.swift
//  SpendlyAI
//

import Foundation
import SwiftData

@Model
final class DailyBudgetSnapshot {
    var date: Date
    var calculatedAvailableAmount: Decimal
    var spentToday: Decimal
    var remainingSafeAmount: Decimal

    init(
        date: Date = .now,
        calculatedAvailableAmount: Decimal = 0,
        spentToday: Decimal = 0,
        remainingSafeAmount: Decimal = 0
    ) {
        self.date = date
        self.calculatedAvailableAmount = calculatedAvailableAmount
        self.spentToday = spentToday
        self.remainingSafeAmount = remainingSafeAmount
    }
}
