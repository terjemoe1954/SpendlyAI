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
    case subscriptions
    case other
    case groceries
    case insurance
    case gifts
    case health
    case home
    case income
    case clothing
    case communication
    case gambling
    case savings
    case transport
    case withdrawals
    case entertainment
    case developer

    // Retained so backups and existing data from earlier versions still decode.
    case salary
    case freelance
    case benefits
    case investment
    case gift
    case refund

    static var allCases: [IncomeCategory] {
        [.subscriptions, .other, .groceries, .insurance, .gifts, .health, .home,
         .income, .clothing, .communication, .gambling, .savings, .transport,
         .withdrawals, .entertainment, .developer]
    }

    var normalizedCategory: IncomeCategory {
        switch self {
        case .salary, .freelance, .benefits, .investment, .refund:
            .income
        case .gift:
            .gifts
        default:
            self
        }
    }

    var titleKey: LocalizedStringKey {
        switch normalizedCategory {
        case .subscriptions: "expenseCategory.subscriptions"
        case .other: "category.other"
        case .groceries: "category.groceries"
        case .insurance: "expenseCategory.insurance"
        case .gifts: "category.gifts"
        case .health: "category.health"
        case .home: "category.home"
        case .income: "category.income"
        case .clothing: "category.clothing"
        case .communication: "category.communication"
        case .gambling: "category.gambling"
        case .savings: "category.savings"
        case .transport: "category.transport"
        case .withdrawals: "category.withdrawals"
        case .entertainment: "category.entertainment"
        case .developer: "category.developer"
        case .salary, .freelance, .benefits, .investment, .gift, .refund:
            "category.income"
        }
    }

    var systemImage: String {
        switch normalizedCategory {
        case .subscriptions: "repeat"
        case .other: "circle.grid.2x2"
        case .groceries: "basket"
        case .insurance: "shield"
        case .gifts: "gift"
        case .health: "cross.case"
        case .home: "house"
        case .income: "arrow.down.circle"
        case .clothing: "tshirt"
        case .communication: "phone"
        case .gambling: "dice"
        case .savings: "banknote"
        case .transport: "car"
        case .withdrawals: "banknote"
        case .entertainment: "ticket"
        case .developer: "hammer"
        case .salary, .freelance, .benefits, .investment, .gift, .refund:
            "arrow.down.circle"
        }
    }
}
