//
//  GoalsView.swift
//  SpendlyAI
//

import SwiftUI

struct GoalsView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(titleKey: "goals.title", systemImage: "target")
                .navigationTitle("tab.goals")
        }
    }
}

#Preview {
    GoalsView()
}
