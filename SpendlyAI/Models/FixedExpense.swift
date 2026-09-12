//
//  FixedExpense.swift
//  SpendlyAI
//

import Foundation
import SwiftData

@Model
final class FixedExpense {
    var name: String
    var amount: Decimal
    var dueDay: Int
    var category: ExpenseCategory
    var recurrence: ExpenseRecurrence
    var isActive: Bool

    init(
        name: String,
        amount: Decimal,
        dueDay: Int,
        category: ExpenseCategory = .other,
        recurrence: ExpenseRecurrence = .monthly,
        isActive: Bool = true
    ) {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.category = category
        self.recurrence = recurrence
        self.isActive = isActive
    }
}
