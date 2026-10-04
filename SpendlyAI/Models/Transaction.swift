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
    var dueDate: Date?
    var settledDate: Date?
    var paymentStatusRawValue: String?

    var paymentStatus: PaymentStatus {
        get { paymentStatusRawValue.flatMap(PaymentStatus.init(rawValue:)) ?? .settled }
        set { paymentStatusRawValue = newValue.rawValue }
    }

    func effectivePaymentStatus(now: Date = .now, calendar: Calendar = .current) -> PaymentStatus {
        paymentStatus.effectiveStatus(dueDate: dueDate, now: now, calendar: calendar)
    }

    init(
        amount: Decimal,
        date: Date = .now,
        category: SpendingCategory = .other,
        transactionDescription: String = "",
        isEssential: Bool = false,
        notes: String? = nil,
        dueDate: Date? = nil,
        settledDate: Date? = nil,
        paymentStatus: PaymentStatus = .settled
    ) {
        self.amount = amount
        self.date = date
        self.category = category
        self.transactionDescription = transactionDescription
        self.isEssential = isEssential
        self.notes = notes
        self.dueDate = dueDate
        self.settledDate = settledDate
        self.paymentStatusRawValue = paymentStatus.rawValue
    }
}
