//
//  PlanAndPlusView.swift
//  SpendlyAI
//

import SwiftUI

struct PlanAndPlusView: View {
    @State private var plusProduct: PurchaseProduct?
    @State private var purchaseState: PurchaseState = .unavailable
    @State private var isLoadingProduct = false
    @State private var isPurchasing = false
    @State private var alert: PlanAlert?

    private let purchaseService = PurchaseService()

    var body: some View {
        List {
            Section {
                Text("plan.mvpNotice")
                    .foregroundStyle(.secondary)
            }

            Section("plan.free.title") {
                PlanFeatureRow(titleKey: "plan.free.manualBudget", systemImage: "pencil.and.list.clipboard")
                PlanFeatureRow(titleKey: "plan.free.transactions", systemImage: "cart")
                PlanFeatureRow(titleKey: "plan.free.dailyBudget", systemImage: "wallet.pass")
                PlanFeatureRow(titleKey: "plan.free.oneGoal", systemImage: "target")
                PlanFeatureRow(titleKey: "plan.free.limitedAI", systemImage: "sparkles")
            }

            Section("plan.plus.title") {
                PlanFeatureRow(titleKey: "plan.plus.moreGoals", systemImage: "target")
                PlanFeatureRow(titleKey: "plan.plus.moreAI", systemImage: "sparkles")
                PlanFeatureRow(titleKey: "plan.plus.forecasts", systemImage: "chart.line.uptrend.xyaxis")
                PlanFeatureRow(titleKey: "plan.plus.weeklySummary", systemImage: "calendar.badge.clock")
                PlanFeatureRow(titleKey: "plan.plus.scenarios", systemImage: "slider.horizontal.3")
                PlanFeatureRow(titleKey: "plan.plus.exportReports", systemImage: "square.and.arrow.up")
                PlanFeatureRow(titleKey: "plan.plus.sync", systemImage: "icloud")
            }

            Section {
                if let plusProduct {
                    LabeledContent(plusProduct.displayName, value: plusProduct.displayPrice)
                } else {
                    Text(isLoadingProduct ? "plan.store.loading" : "plan.store.unavailable")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await purchasePlus()
                    }
                } label: {
                    Label("plan.store.subscribe", systemImage: "plus.circle")
                }
                .disabled(plusProduct == nil || isPurchasing)

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Label("plan.store.restore", systemImage: "arrow.clockwise")
                }
                .disabled(isPurchasing)

                LabeledContent("plan.store.status", value: statusTitle)
            } header: {
                Text("plan.store.title")
            } footer: {
                Text("plan.store.footer")
            }
        }
        .navigationTitle("plan.title")
        .task {
            await loadPlanState()
        }
        .alert(
            alert?.titleKey ?? "plan.alert.purchaseFailed.title",
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

    private func loadPlanState() async {
        isLoadingProduct = true
        async let loadedProduct = purchaseService.loadPlusProduct()
        async let loadedState = purchaseService.currentPlusState()
        plusProduct = await loadedProduct
        purchaseState = await loadedState
        if plusProduct == nil, purchaseState == .notPurchased {
            purchaseState = .unavailable
        }
        isLoadingProduct = false
    }

    private func purchasePlus() async {
        isPurchasing = true
        let result = await purchaseService.purchasePlus()
        isPurchasing = false

        switch result {
        case .success(let state):
            purchaseState = state
            alert = .purchaseComplete
        case .failure(.cancelled):
            break
        case .failure(.pending):
            alert = .purchasePending
        case .failure:
            alert = .purchaseFailed
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        let result = await purchaseService.restorePurchases()
        isPurchasing = false

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
    case purchaseComplete
    case purchasePending
    case purchaseFailed
    case restoreComplete
    case restoreEmpty
    case restoreFailed

    var titleKey: LocalizedStringKey {
        switch self {
        case .purchaseComplete:
            "plan.alert.purchaseComplete.title"
        case .purchasePending:
            "plan.alert.purchasePending.title"
        case .purchaseFailed:
            "plan.alert.purchaseFailed.title"
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
        case .purchaseComplete:
            "plan.alert.purchaseComplete.message"
        case .purchasePending:
            "plan.alert.purchasePending.message"
        case .purchaseFailed:
            "plan.alert.purchaseFailed.message"
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
