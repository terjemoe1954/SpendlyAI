//
//  AppAppearance.swift
//  SpendlyAI
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "selectedAppearance"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            "appearance.system"
        case .light:
            "appearance.light"
        case .dark:
            "appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
