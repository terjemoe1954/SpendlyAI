//
//  RootTabView.swift
//  SpendlyAI
//

import SwiftUI

struct RootTabView: View {
    @AppStorage(AppAppearance.storageKey) private var selectedAppearance = AppAppearance.system.rawValue

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
    }
}

#Preview {
    RootTabView()
}
