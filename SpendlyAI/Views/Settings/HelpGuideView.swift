import SwiftUI

struct HelpGuideView: View {
    var body: some View {
        List {
            Section {
                HelpNavigationRow(
                    titleKey: "help.profile.title",
                    subtitleKey: "help.profile.subtitle",
                    systemImage: "person.crop.circle",
                    topic: .profile
                )
                HelpNavigationRow(
                    titleKey: "help.dailyBudget.title",
                    subtitleKey: "help.dailyBudget.subtitle",
                    systemImage: "calendar.badge.clock",
                    topic: .dailyBudget
                )
                HelpNavigationRow(
                    titleKey: "help.planning.title",
                    subtitleKey: "help.planning.subtitle",
                    systemImage: "target",
                    topic: .planning
                )
                HelpNavigationRow(
                    titleKey: "help.transactions.title",
                    subtitleKey: "help.transactions.subtitle",
                    systemImage: "list.bullet.rectangle",
                    topic: .transactions
                )
                HelpNavigationRow(
                    titleKey: "help.incomes.title",
                    subtitleKey: "help.incomes.subtitle",
                    systemImage: "banknote",
                    topic: .incomes
                )
                HelpNavigationRow(
                    titleKey: "help.fixedExpenses.title",
                    subtitleKey: "help.fixedExpenses.subtitle",
                    systemImage: "calendar.badge.exclamationmark",
                    topic: .fixedExpenses
                )
                HelpNavigationRow(
                    titleKey: "help.reports.title",
                    subtitleKey: "help.reports.subtitle",
                    systemImage: "doc.text.magnifyingglass",
                    topic: .reports
                )
                HelpNavigationRow(
                    titleKey: "help.backup.title",
                    subtitleKey: "help.backup.subtitle",
                    systemImage: "externaldrive",
                    topic: .backup
                )
                HelpNavigationRow(
                    titleKey: "help.faq.title",
                    subtitleKey: "help.faq.subtitle",
                    systemImage: "questionmark.circle",
                    topic: .faq
                )
            } header: {
                Text("help.section.gettingStarted")
            }
        }
        .navigationTitle("help.title")
        .navigationDestination(for: HelpTopic.self) { topic in
            HelpTopicView(topic: topic)
        }
    }
}

private struct HelpNavigationRow: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String
    let topic: HelpTopic

    var body: some View {
        NavigationLink(value: topic) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                    Text(subtitleKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        List {
            ForEach(topic.sections) { section in
                Section(section.title) {
                    Text(section.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .navigationTitle(topic.titleKey)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum HelpTopic: String, Hashable {
    case profile
    case dailyBudget
    case planning
    case transactions
    case incomes
    case fixedExpenses
    case reports
    case backup
    case faq

    var titleKey: LocalizedStringKey {
        switch self {
        case .profile: "help.profile.title"
        case .dailyBudget: "help.dailyBudget.title"
        case .planning: "help.planning.title"
        case .transactions: "help.transactions.title"
        case .incomes: "help.incomes.title"
        case .fixedExpenses: "help.fixedExpenses.title"
        case .reports: "help.reports.title"
        case .backup: "help.backup.title"
        case .faq: "help.faq.title"
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .profile:
            [
                HelpSection(titleKey: "help.profile.setup.title", bodyKey: "help.profile.setup.body"),
                HelpSection(titleKey: "help.profile.update.title", bodyKey: "help.profile.update.body")
            ]
        case .dailyBudget:
            [
                HelpSection(titleKey: "help.dailyBudget.formula.title", bodyKey: "help.dailyBudget.formula.body"),
                HelpSection(titleKey: "help.dailyBudget.today.title", bodyKey: "help.dailyBudget.today.body"),
                HelpSection(
                    titleKey: "What is included in Safe to Spend",
                    bodyKey: "Safe to Spend is calculated from income minus paid purchases earlier in the budget period, upcoming active fixed expenses due before the next income date, planned savings, and the minimum buffer. The remainder is divided by the number of days until the next income. Purchases paid today are then subtracted from today's amount. Monthly, quarterly, semiannual, annual, and custom fixed expenses are included only when their actual next due date falls within the period. Purchases marked Waiting are not currently reserved in advance, even when they have a due date."
                )
            ]
        case .planning:
            [
                HelpSection(titleKey: "help.planning.buffer.title", bodyKey: "help.planning.buffer.body"),
                HelpSection(titleKey: "help.planning.expenses.title", bodyKey: "help.planning.expenses.body"),
                HelpSection(titleKey: "help.planning.goals.title", bodyKey: "help.planning.goals.body")
            ]
        case .transactions:
            [
                HelpSection(titleKey: "help.transactions.add.title", bodyKey: "help.transactions.add.body"),
                HelpSection(titleKey: "help.transactions.edit.title", bodyKey: "help.transactions.edit.body")
            ]
        case .incomes:
            [
                HelpSection(titleKey: "help.incomes.add.title", bodyKey: "help.incomes.add.body"),
                HelpSection(titleKey: "help.incomes.status.title", bodyKey: "help.incomes.status.body")
            ]
        case .fixedExpenses:
            [
                HelpSection(titleKey: "help.fixedExpenses.manage.title", bodyKey: "help.fixedExpenses.manage.body"),
                HelpSection(titleKey: "help.fixedExpenses.status.title", bodyKey: "help.fixedExpenses.status.body")
            ]
        case .reports:
            [
                HelpSection(titleKey: "help.reports.summary.title", bodyKey: "help.reports.summary.body"),
                HelpSection(titleKey: "help.reports.export.title", bodyKey: "help.reports.export.body")
            ]
        case .backup:
            [
                HelpSection(titleKey: "help.backup.export.title", bodyKey: "help.backup.export.body"),
                HelpSection(titleKey: "help.backup.restore.title", bodyKey: "help.backup.restore.body"),
                HelpSection(titleKey: "help.backup.safety.title", bodyKey: "help.backup.safety.body")
            ]
        case .faq:
            [
                HelpSection(titleKey: "help.faq.changes.question", bodyKey: "help.faq.changes.answer"),
                HelpSection(titleKey: "help.faq.sync.question", bodyKey: "help.faq.sync.answer"),
                HelpSection(titleKey: "help.faq.privacy.question", bodyKey: "help.faq.privacy.answer")
            ]
        }
    }
}

private struct HelpSection: Identifiable {
    let id: String
    let title: String
    let body: String

    init(titleKey: String.LocalizationValue, bodyKey: String.LocalizationValue) {
        title = String(localized: titleKey)
        body = String(localized: bodyKey)
        id = title
    }
}


#Preview {
    NavigationStack {
        HelpGuideView()
    }
}
