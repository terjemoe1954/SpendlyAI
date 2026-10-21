import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MySavingsImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isSelectingFile = false
    @State private var pendingPlan: MySavingsImportPlan?
    @State private var isShowingConfirmation = false
    @State private var notice: MySavingsImportNotice?

    private let importService = MySavingsImportService()

    var body: some View {
        Form {
            Section {
                Button {
                    isSelectingFile = true
                } label: {
                    Label("mysavings.import.chooseFile", systemImage: "doc.badge.plus")
                }
            } header: {
                Text("mysavings.import.section.title")
            } footer: {
                Text("mysavings.import.section.footer")
            }
        }
        .navigationTitle("mysavings.import.title")
        .fileImporter(
            isPresented: $isSelectingFile,
            allowedContentTypes: [.json]
        ) { result in
            handleFileSelection(result)
        }
        .sheet(item: $pendingPlan) { plan in
            MySavingsImportPreview(
                plan: plan,
                onCancel: {
                    pendingPlan = nil
                },
                onImport: {
                    isShowingConfirmation = true
                }
            )
            .confirmationDialog(
                "mysavings.import.confirm.title",
                isPresented: $isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button("mysavings.import.confirm.action") {
                    importPendingPlan()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("mysavings.import.confirm.message")
            }
        }
        .alert(
            notice?.title ?? "mysavings.import.error.title",
            isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) {
                notice = nil
            }
        } message: {
            if let notice {
                Text(notice.message)
            }
        }
    }

    private func handleFileSelection(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                pendingPlan = try importService.decode(Data(contentsOf: url))
            } catch let error as MySavingsImportError {
                switch error {
                case .unsupportedVersion:
                    notice = .unsupportedVersion
                case .unreadableFile, .noImportableTransactions:
                    notice = .invalidFile
                }
            } catch {
                notice = .invalidFile
            }
        case .failure:
            notice = .fileSelectionFailed
        }
    }

    private func importPendingPlan() {
        guard let pendingPlan else { return }

        do {
            try importService.importPlan(pendingPlan, into: modelContext)
            self.pendingPlan = nil
            notice = .importSucceeded
        } catch {
            notice = .importFailed
        }
    }
}

private struct MySavingsImportPreview: View {
    let plan: MySavingsImportPlan
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("mysavings.import.preview.file") {
                    LabeledContent("mysavings.import.preview.date") {
                        Text(plan.exportedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent(
                        "mysavings.import.preview.version",
                        value: String(plan.formatVersion)
                    )
                }

                Section("mysavings.import.preview.contents") {
                    LabeledContent(
                        "mysavings.import.preview.expenses",
                        value: String(plan.expenses.count)
                    )
                    LabeledContent(
                        "mysavings.import.preview.incomes",
                        value: String(plan.incomes.count)
                    )
                    LabeledContent(
                        "backup.summary.fixedExpenses",
                        value: String(plan.fixedExpenses.count)
                    )
                    if plan.skippedCount > 0 {
                        LabeledContent(
                            "mysavings.import.preview.skipped",
                            value: String(plan.skippedCount)
                        )
                    }
                }

                Section {
                    Text("mysavings.import.preview.warning")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("mysavings.import.preview.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("mysavings.import.action", action: onImport)
                }
            }
        }
    }
}

private enum MySavingsImportNotice {
    case fileSelectionFailed
    case invalidFile
    case unsupportedVersion
    case importSucceeded
    case importFailed

    var title: LocalizedStringKey {
        switch self {
        case .importSucceeded:
            "mysavings.import.success.title"
        case .fileSelectionFailed, .invalidFile, .unsupportedVersion, .importFailed:
            "mysavings.import.error.title"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .fileSelectionFailed:
            "mysavings.import.fileSelectionFailed.message"
        case .invalidFile:
            "mysavings.import.invalidFile.message"
        case .unsupportedVersion:
            "mysavings.import.unsupportedVersion.message"
        case .importSucceeded:
            "mysavings.import.success.message"
        case .importFailed:
            "mysavings.import.failure.message"
        }
    }
}
