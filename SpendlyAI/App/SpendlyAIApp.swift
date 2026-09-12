//
//  SpendlyAIApp.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

@main
struct SpendlyAIApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
