import Foundation
import SwiftData
import SwiftUI

@Model
final class Income {
    var amount: Decimal
    var date: Date
    var category: IncomeCategory
    var incomeDescription: String
    var notes: String?
    var recurrence: IncomeRecurrence = IncomeRecurrence.oneTime
    var isActive: Bool = true
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
        category: IncomeCategory = .other,
        incomeDescription: String = "",
        notes: String? = nil,
        recurrence: IncomeRecurrence = .oneTime,
        isActive: Bool = true,
        dueDate: Date? = nil,
        settledDate: Date? = nil,
        paymentStatus: PaymentStatus = .settled
    ) {
        self.amount = amount
        self.date = date
        self.category = category
        self.incomeDescription = incomeDescription
        self.notes = notes
        self.recurrence = recurrence
        self.isActive = isActive
        self.dueDate = dueDate
        self.settledDate = settledDate
        self.paymentStatusRawValue = paymentStatus.rawValue
    }
}

enum IncomeRecurrence: String, Codable, CaseIterable {
    case oneTime
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var titleKey: LocalizedStringKey {
        switch self {
        case .oneTime: "incomeRecurrence.oneTime"
        case .weekly: "incomeRecurrence.weekly"
        case .biweekly: "incomeRecurrence.biweekly"
        case .monthly: "incomeRecurrence.monthly"
        case .quarterly: "incomeRecurrence.quarterly"
        case .yearly: "incomeRecurrence.yearly"
        }
    }
}

enum IncomeCategory: String, Codable, CaseIterable {
    case salary
    case freelance
    case benefits
    case investment
    case gift
    case refund
    case other

    var titleKey: LocalizedStringKey {
        switch self {
        case .salary: "incomeCategory.salary"
        case .freelance: "incomeCategory.freelance"
        case .benefits: "incomeCategory.benefits"
        case .investment: "incomeCategory.investment"
        case .gift: "incomeCategory.gift"
        case .refund: "incomeCategory.refund"
        case .other: "incomeCategory.other"
        }
    }

    var systemImage: String {
        switch self {
        case .salary: "banknote"
        case .freelance: "briefcase"
        case .benefits: "building.columns"
        case .investment: "chart.line.uptrend.xyaxis"
        case .gift: "gift"
        case .refund: "arrow.uturn.backward.circle"
        case .other: "plus.circle"
        }
    }
}
