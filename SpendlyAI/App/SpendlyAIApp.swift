//
//  SpendlyAIApp.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

@main
struct SpendlyAIApp: App {
    private let purchaseService = PurchaseService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    await purchaseService.listenForTransactions()
                }
        }
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ])
    }
}
