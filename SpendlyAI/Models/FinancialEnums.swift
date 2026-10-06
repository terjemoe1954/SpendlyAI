//
//  FinancialEnums.swift
//  SpendlyAI
//

import Foundation

enum MoneyFormatter {
    static func string(
        from amount: Decimal,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }
}

enum MoneyParser {
    static func decimal(from text: String) -> Decimal? {
        let compactText = text.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !compactText.isEmpty else { return nil }
        guard compactText.enumerated().allSatisfy({ offset, character in
            character.isNumber || character == "," || character == "." ||
                ((character == "-" || character == "+") && offset == 0)
        }) else {
            return nil
        }

        let decimalSeparatorIndex = [
            compactText.lastIndex(of: ","),
            compactText.lastIndex(of: ".")
        ]
        .compactMap { $0 }
        .max()

        let normalizedText: String
        if let decimalSeparatorIndex {
            let integerPart = compactText[..<decimalSeparatorIndex]
                .filter { $0 != "," && $0 != "." }
            let fractionStart = compactText.index(after: decimalSeparatorIndex)
            let fractionPart = compactText[fractionStart...]
                .filter { $0 != "," && $0 != "." }
            normalizedText = String(integerPart) + "." + String(fractionPart)
        } else {
            normalizedText = compactText
        }

        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX"))
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case subscriptions
    case other
    case groceries
    case insurance
    case gifts
    case health
    case housing
    case income
    case clothing
    case communication
    case gambling
    case savings
    case transport
    case withdrawals
    case entertainment
    case developer

    // Retained so existing data from earlier versions can still be decoded.
    case utilities
    case debt
    case childcare

    static var allCases: [ExpenseCategory] {
        [.subscriptions, .other, .groceries, .insurance, .gifts, .health, .housing,
         .income, .clothing, .communication, .gambling, .savings, .transport,
         .withdrawals, .entertainment, .developer]
    }
}

enum ExpenseRecurrence: String, Codable, CaseIterable {
    case monthly
    case quarterly
    case semiannual
    case yearly
    case custom

    // Retained so existing data from earlier versions can still be decoded.
    case weekly
    case biweekly

    static var allCases: [ExpenseRecurrence] {
        [.monthly, .quarterly, .semiannual, .yearly, .custom]
    }
}

enum SpendingCategory: String, Codable, CaseIterable {
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

    // Retained so existing data from earlier versions can still be decoded.
    case food
    case shopping
    case bills

    static var allCases: [SpendingCategory] {
        [.subscriptions, .other, .groceries, .insurance, .gifts, .health, .home,
         .income, .clothing, .communication, .gambling, .savings, .transport,
         .withdrawals, .entertainment, .developer]
    }
}

enum GoalPriority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
}
