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
    case backup
    case faq

    var titleKey: LocalizedStringKey {
        switch self {
        case .profile: "help.profile.title"
        case .dailyBudget: "help.dailyBudget.title"
        case .planning: "help.planning.title"
        case .transactions: "help.transactions.title"
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
                HelpSection(titleKey: "help.dailyBudget.today.title", bodyKey: "help.dailyBudget.today.body")
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
