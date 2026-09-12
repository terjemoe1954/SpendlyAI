//
//  FinancialEnums.swift
//  SpendlyAI
//

import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case housing
    case utilities
    case insurance
    case transport
    case subscriptions
    case debt
    case childcare
    case groceries
    case health
    case other
}

enum ExpenseRecurrence: String, Codable, CaseIterable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
}

enum SpendingCategory: String, Codable, CaseIterable {
    case food
    case groceries
    case transport
    case shopping
    case entertainment
    case health
    case bills
    case savings
    case other
}

enum GoalPriority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
}
