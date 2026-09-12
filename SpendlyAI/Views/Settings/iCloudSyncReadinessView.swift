//
//  iCloudSyncReadinessView.swift
//  SpendlyAI
//

import SwiftUI

struct iCloudSyncReadinessView: View {
    private let report = CloudSyncReadinessService().makeReport()

    var body: some View {
        List {
            Section("sync.decision.title") {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        decisionTitle
                            .font(.headline)
                        decisionMessage
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "icloud")
                        .foregroundStyle(AppStyle.accentColor)
                }
            }

            Section("sync.mvp.title") {
                Label("sync.mvp.notBlocking", systemImage: report.shouldBlockMVP ? "xmark.circle" : "checkmark.circle")
                    .foregroundStyle(report.shouldBlockMVP ? .red : .green)

                Text("sync.mvp.message")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(report.pendingRequirements) { requirement in
                    Label {
                        requirementTitle(for: requirement)
                    } icon: {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("sync.requirements.title")
            } footer: {
                Text("sync.requirements.footer")
            }

            Section("sync.testing.title") {
                SyncTestingRow(titleKey: "sync.testing.iphoneIpad", systemImage: "iphone.and.arrow.forward")
                SyncTestingRow(titleKey: "sync.testing.conflicts", systemImage: "arrow.triangle.branch")
                SyncTestingRow(titleKey: "sync.testing.offlineOnline", systemImage: "wifi.slash")
                SyncTestingRow(titleKey: "sync.testing.reinstall", systemImage: "arrow.clockwise.icloud")
            }
        }
        .navigationTitle("sync.title")
    }

    private var decisionTitle: Text {
        switch report.decision {
        case .localFirstMVP:
            Text("sync.decision.localFirst.title")
        case .readyForCloudKit:
            Text("sync.decision.ready.title")
        }
    }

    private var decisionMessage: Text {
        switch report.decision {
        case .localFirstMVP:
            Text("sync.decision.localFirst.message")
        case .readyForCloudKit:
            Text("sync.decision.ready.message")
        }
    }

    private func requirementTitle(for requirement: CloudSyncRequirement) -> Text {
        switch requirement {
        case .iCloudCapability:
            Text("sync.requirement.iCloudCapability")
        case .backgroundRemoteNotifications:
            Text("sync.requirement.backgroundRemoteNotifications")
        case .cloudKitCompatibleSchema:
            Text("sync.requirement.cloudKitCompatibleSchema")
        case .developmentSchemaInitialized:
            Text("sync.requirement.developmentSchemaInitialized")
        case .productionSchemaPromoted:
            Text("sync.requirement.productionSchemaPromoted")
        case .multiDeviceValidation:
            Text("sync.requirement.multiDeviceValidation")
        case .conflictValidation:
            Text("sync.requirement.conflictValidation")
        case .offlineOnlineValidation:
            Text("sync.requirement.offlineOnlineValidation")
        case .reinstallValidation:
            Text("sync.requirement.reinstallValidation")
        }
    }
}

private struct SyncTestingRow: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(titleKey, systemImage: systemImage)
    }
}

#Preview {
    NavigationStack {
        iCloudSyncReadinessView()
    }
}
