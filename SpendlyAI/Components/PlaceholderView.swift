//
//  PlaceholderView.swift
//  SpendlyAI
//

import SwiftUI

struct PlaceholderView: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppStyle.accentColor)

            Text(titleKey)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppStyle.screenBackground)
    }
}
