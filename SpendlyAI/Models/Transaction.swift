//
//  Transaction.swift
//  SpendlyAI
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Decimal
    var date: Date
    var category: SpendingCategory
    var transactionDescription: String
    var isEssential: Bool
    var notes: String?

    init(
        amount: Decimal,
        date: Date = .now,
        category: SpendingCategory = .other,
        transactionDescription: String = "",
        isEssential: Bool = false,
        notes: String? = nil
    ) {
        self.amount = amount
        self.date = date
        self.category = category
        self.transactionDescription = transactionDescription
        self.isEssential = isEssential
        self.notes = notes
    }
}
