//
//  RootView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(AppAppearance.storageKey) private var selectedAppearance = AppAppearance.system.rawValue
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserFinancialProfile.updatedAt, order: .reverse) private var profiles: [UserFinancialProfile]

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .preferredColorScheme(AppAppearance(rawValue: selectedAppearance)?.colorScheme)
        .task(id: profiles.first?.persistentModelID) {
            removeLegacyProfileAmounts()
        }
    }

    private func removeLegacyProfileAmounts() {
        guard let profile = profiles.first,
              profile.monthlyNetIncome != 0 || profile.minimumBuffer != 0 else { return }
        profile.monthlyNetIncome = 0
        profile.minimumBuffer = 0
        profile.updatedAt = .now
        try? modelContext.save()
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            Income.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
