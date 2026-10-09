import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppStyle.accentColor)
                        .accessibilityHidden(true)

                    Text("onboarding.welcome.title")
                        .font(.largeTitle.bold())

                    Text("onboarding.welcome.message")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Label("onboarding.info.transactions", systemImage: "list.bullet.rectangle")
                        Label("onboarding.info.income", systemImage: "arrow.down.circle")
                        Label("onboarding.info.fixedExpenses", systemImage: "repeat")
                        Label("onboarding.info.backup", systemImage: "externaldrive")
                    }
                    .font(.headline)
                    .padding(AppSpacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))

                    Button("onboarding.start") {
                        startUsingApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(AppSpacing.large)
                .frame(maxWidth: .infinity)
            }
            .background(AppStyle.screenBackground)
            .navigationTitle("onboarding.title")
        }
    }

    private func startUsingApp() {
        let now = Date.now
        modelContext.insert(UserFinancialProfile(
            monthlyNetIncome: 0,
            paydayDay: 1,
            budgetPeriodStart: now,
            budgetPeriodEnd: now,
            currencyCode: "NOK",
            minimumBuffer: 0,
            createdAt: now,
            updatedAt: now
        ))
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            Income.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
