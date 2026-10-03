//
//  PlanAndPlusView.swift
//  SpendlyAI
//

import SwiftUI

struct PlanAndPlusView: View {
    @State private var purchaseState: PurchaseState = .unavailable
    @State private var isRestoring = false
    @State private var alert: PlanAlert?

    private let purchaseService = PurchaseService()

    var body: some View {
        List {
            Section("plan.free.title") {
                PlanFeatureRow(titleKey: "plan.free.manualBudget", systemImage: "pencil.and.list.clipboard")
                PlanFeatureRow(titleKey: "plan.free.transactions", systemImage: "cart")
                PlanFeatureRow(titleKey: "plan.free.dailyBudget", systemImage: "wallet.pass")
                PlanFeatureRow(titleKey: "plan.free.oneGoal", systemImage: "target")
                PlanFeatureRow(titleKey: "plan.free.limitedAI", systemImage: "sparkles")
            }

            Section {
                LabeledContent("plan.store.status", value: statusTitle)

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Label("plan.store.restore", systemImage: "arrow.clockwise")
                }
                .disabled(isRestoring)
            } footer: {
                Text("plan.store.footer")
            }
        }
        .navigationTitle("plan.title")
        .task {
            purchaseState = await purchaseService.currentPlusState()
        }
        .alert(
            alert?.titleKey ?? "plan.alert.restoreFailed.title",
            isPresented: Binding(
                get: { alert != nil },
                set: { isPresented in
                    if !isPresented {
                        alert = nil
                    }
                }
            )
        ) {
            Button("common.ok", role: .cancel) {
                alert = nil
            }
        } message: {
            if let alert {
                Text(alert.messageKey)
            }
        }
    }

    private var statusTitle: String {
        switch purchaseState {
        case .unavailable:
            String(localized: "plan.status.unavailable")
        case .notPurchased:
            String(localized: "plan.status.free")
        case .purchased:
            String(localized: "plan.status.plus")
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        let result = await purchaseService.restorePurchases()
        isRestoring = false

        switch result {
        case .success(let state):
            purchaseState = state
            alert = state == .purchased ? .restoreComplete : .restoreEmpty
        case .failure:
            alert = .restoreFailed
        }
    }
}

private struct PlanFeatureRow: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(titleKey, systemImage: systemImage)
    }
}

private enum PlanAlert {
    case restoreComplete
    case restoreEmpty
    case restoreFailed

    var titleKey: LocalizedStringKey {
        switch self {
        case .restoreComplete:
            "plan.alert.restoreComplete.title"
        case .restoreEmpty:
            "plan.alert.restoreEmpty.title"
        case .restoreFailed:
            "plan.alert.restoreFailed.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .restoreComplete:
            "plan.alert.restoreComplete.message"
        case .restoreEmpty:
            "plan.alert.restoreEmpty.message"
        case .restoreFailed:
            "plan.alert.restoreFailed.message"
        }
    }
}

#Preview {
    NavigationStack {
        PlanAndPlusView()
    }
}
