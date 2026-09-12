//
//  RootView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(AppAppearance.storageKey) private var selectedAppearance = AppAppearance.system.rawValue
    @Query private var profiles: [UserFinancialProfile]

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .preferredColorScheme(AppAppearance(rawValue: selectedAppearance)?.colorScheme)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
