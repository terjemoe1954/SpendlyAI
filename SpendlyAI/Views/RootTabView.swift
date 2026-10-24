//
// RootTabView.swift
// SpendlyAI
//

import SwiftData
import SwiftUI

struct RootTabView: View {
    @AppStorage(AppAppearance.storageKey) private var selectedAppearance = AppAppearance.system.rawValue
    @Query private var transactions: [Transaction]
    @Query private var fixedExpenses: [FixedExpense]
    @State private var showsOverdueBills = false
    @State private var checkedOverdueBills = false

    private var overdueCount: Int {
        let transactionCount = transactions.filter { $0.effectivePaymentStatus() == .overdue }.count
        let fixedCount = fixedExpenses.filter {
            $0.isActive && $0.dueDate != nil && $0.effectivePaymentStatus() == .overdue
        }.count
        return transactionCount + fixedCount
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("tab.home", systemImage: "house")
                }

            TransactionsView()
                .tabItem {
                    Label("tab.transactions", systemImage: "list.bullet.rectangle")
                }

            AIView()
                .tabItem {
                    Label("tab.ai", systemImage: "sparkles")
                }

            GoalsView()
                .tabItem {
                    Label("tab.goals", systemImage: "target")
                }

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
        }
        .tint(AppStyle.accentColor)
        .preferredColorScheme(AppAppearance(rawValue: selectedAppearance)?.colorScheme)
        .task {
            guard !checkedOverdueBills else { return }
            checkedOverdueBills = true
            showsOverdueBills = overdueCount > 0
        }
        .sheet(isPresented: $showsOverdueBills) {
            NavigationStack {
                UnpaidBillsView(overdueOnly: true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") { showsOverdueBills = false }
                        }
                    }
            }
        }
    }
}

#Preview {
    RootTabView()
}
