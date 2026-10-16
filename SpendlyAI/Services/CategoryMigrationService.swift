import Foundation
import SwiftData

@MainActor
struct CategoryMigrationService {
    private static let migrationKey = "categoryMigration.flatStandard.v1"

    func migrateIfNeeded(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.migrationKey) else { return }

        do {
            try migrateTransactions(modelContext.fetch(FetchDescriptor<Transaction>()))
            try migrateIncomes(modelContext.fetch(FetchDescriptor<Income>()))
            try migrateFixedExpenses(modelContext.fetch(FetchDescriptor<FixedExpense>()))
            try modelContext.save()
            defaults.set(true, forKey: Self.migrationKey)
        } catch {
            // Leave the marker unset so a temporary persistence error can be retried.
        }
    }

    private func migrateTransactions(_ transactions: [Transaction]) throws {
        for transaction in transactions {
            let text = searchableText(transaction.transactionDescription, transaction.notes)

            if transaction.category == .other && isDiningOut(text) {
                transaction.category = .diningOut
            } else if transaction.category == .subscriptions && isPhoneOrInternet(text) {
                transaction.category = .communication
            } else if containsAny(text, ["restskatt"]) {
                transaction.category = .withdrawals
            } else if isAppDevelopment(text) {
                transaction.category = .developer
            } else if containsAny(text, ["brilleabonnement"]) {
                transaction.category = .health
            }
        }
    }

    private func migrateIncomes(_ incomes: [Income]) throws {
        for income in incomes {
            let text = searchableText(income.incomeDescription, income.notes)

            if income.category == .other && isDiningOut(text) {
                income.category = .diningOut
            } else if income.category == .subscriptions && isPhoneOrInternet(text) {
                income.category = .communication
            } else if containsAny(text, ["restskatt"]) {
                income.category = .withdrawals
            } else if isAppDevelopment(text) {
                income.category = .developer
            } else if containsAny(text, ["brilleabonnement"]) {
                income.category = .health
            }
        }
    }

    private func migrateFixedExpenses(_ expenses: [FixedExpense]) throws {
        for expense in expenses {
            let text = searchableText(expense.name, nil)

            if expense.category == .other && isDiningOut(text) {
                expense.category = .diningOut
            } else if expense.category == .subscriptions && isPhoneOrInternet(text) {
                expense.category = .communication
            } else if containsAny(text, ["restskatt"]) {
                expense.category = .withdrawals
            } else if isAppDevelopment(text) {
                expense.category = .developer
            } else if containsAny(text, ["brilleabonnement"]) {
                expense.category = .health
            }
        }
    }

    private func searchableText(_ title: String, _ notes: String?) -> String {
        [title, notes ?? ""]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func isDiningOut(_ text: String) -> Bool {
        containsAny(text, [
            "burger king",
            "mcdonald",
            "hamburger",
            "fastfood",
            "fast food",
            "ferdigmat"
        ])
    }

    private func isPhoneOrInternet(_ text: String) -> Bool {
        containsAny(text, [
            "mobil",
            "mobilabonnement",
            "mobil abonnement",
            "telefonabonnement",
            "internett",
            "bredband",
            "bredbånd",
            "tv-pakke",
            "tv pakke"
        ])
    }

    private func isAppDevelopment(_ text: String) -> Bool {
        containsAny(text, [
            "chatgpt",
            "apple developer",
            "developer program",
            "app store connect",
            "xcode",
            "testflight",
            "revenuecat"
        ])
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains(where: text.contains)
    }
}
