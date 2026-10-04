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
    case housing
    case utilities
    case insurance
    case transport
    case subscriptions
    case debt
    case childcare
    case groceries
    case health
    case gambling
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
    case gambling
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
