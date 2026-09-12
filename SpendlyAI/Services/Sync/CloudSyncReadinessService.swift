//
//  CloudSyncReadinessService.swift
//  SpendlyAI
//

import Foundation

enum CloudSyncDecision: Equatable {
    case localFirstMVP
    case readyForCloudKit
}

enum CloudSyncRequirement: String, CaseIterable, Equatable, Identifiable {
    case iCloudCapability
    case backgroundRemoteNotifications
    case cloudKitCompatibleSchema
    case developmentSchemaInitialized
    case productionSchemaPromoted
    case multiDeviceValidation
    case conflictValidation
    case offlineOnlineValidation
    case reinstallValidation

    var id: String { rawValue }
}

struct CloudSyncReadinessReport: Equatable {
    let decision: CloudSyncDecision
    let shouldBlockMVP: Bool
    let completedRequirements: Set<CloudSyncRequirement>
    let pendingRequirements: [CloudSyncRequirement]
}

struct CloudSyncReadinessService {
    func makeReport() -> CloudSyncReadinessReport {
        let completedRequirements: Set<CloudSyncRequirement> = []
        let pendingRequirements = CloudSyncRequirement.allCases.filter { !completedRequirements.contains($0) }

        return CloudSyncReadinessReport(
            decision: .localFirstMVP,
            shouldBlockMVP: false,
            completedRequirements: completedRequirements,
            pendingRequirements: pendingRequirements
        )
    }
}

extension CloudSyncDecision {
    var titleKey: String {
        switch self {
        case .localFirstMVP:
            "sync.decision.localFirst.title"
        case .readyForCloudKit:
            "sync.decision.ready.title"
        }
    }

    var messageKey: String {
        switch self {
        case .localFirstMVP:
            "sync.decision.localFirst.message"
        case .readyForCloudKit:
            "sync.decision.ready.message"
        }
    }
}

extension CloudSyncRequirement {
    var titleKey: String {
        switch self {
        case .iCloudCapability:
            "sync.requirement.iCloudCapability"
        case .backgroundRemoteNotifications:
            "sync.requirement.backgroundRemoteNotifications"
        case .cloudKitCompatibleSchema:
            "sync.requirement.cloudKitCompatibleSchema"
        case .developmentSchemaInitialized:
            "sync.requirement.developmentSchemaInitialized"
        case .productionSchemaPromoted:
            "sync.requirement.productionSchemaPromoted"
        case .multiDeviceValidation:
            "sync.requirement.multiDeviceValidation"
        case .conflictValidation:
            "sync.requirement.conflictValidation"
        case .offlineOnlineValidation:
            "sync.requirement.offlineOnlineValidation"
        case .reinstallValidation:
            "sync.requirement.reinstallValidation"
        }
    }
}
