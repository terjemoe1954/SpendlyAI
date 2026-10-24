import Foundation
import SwiftData

@Model
final class FixedExpense {
    var name: String
    var amount: Decimal
    var dueDay: Int
    var category: ExpenseCategory
    var customCategoryName: String?
    var recurrence: ExpenseRecurrence
    var customRecurrenceMonths: Int = 1
    var isActive: Bool
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
        name: String,
        amount: Decimal,
        dueDay: Int,
        category: ExpenseCategory = .other,
        customCategoryName: String? = nil,
        recurrence: ExpenseRecurrence = .monthly,
        customRecurrenceMonths: Int = 1,
        isActive: Bool = true,
        dueDate: Date? = nil,
        settledDate: Date? = nil,
        paymentStatus: PaymentStatus = .pending
    ) {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.category = category
        self.customCategoryName = customCategoryName
        self.recurrence = recurrence
        self.customRecurrenceMonths = max(customRecurrenceMonths, 1)
        self.isActive = isActive
        self.dueDate = dueDate
        self.settledDate = settledDate
        self.paymentStatusRawValue = paymentStatus.rawValue
    }
}
