//
//  SavingsGoal.swift
//  SpendlyAI
//

import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var name: String
    var targetAmount: Decimal
    var targetDate: Date
    var savedAmount: Decimal
    var priority: GoalPriority

    init(
        name: String,
        targetAmount: Decimal,
        targetDate: Date,
        savedAmount: Decimal = 0,
        priority: GoalPriority = .medium
    ) {
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.savedAmount = savedAmount
        self.priority = priority
    }
}
