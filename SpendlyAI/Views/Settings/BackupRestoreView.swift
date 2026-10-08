import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class BackupDocument: WritableDocument {
    static let writableContentTypes: [UTType] = [.json]

    private let data: Data

    init(data: Data) {
        self.data = data
    }

    nonisolated func writer(
        configuration: sending WriteConfiguration
    ) -> sending FileWrapperDocumentWriter<Data> {
        FileWrapperDocumentWriter(configuration) { data, _ in
            FileWrapper(regularFileWithContents: data)
        }
    }

    func snapshot(contentType: UTType) async throws -> sending Data {
        data
    }
}

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserFinancialProfile]
    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var savingsGoals: [SavingsGoal]

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingBackup: SpendlyBackup?
    @State private var notice: BackupNotice?
    @State private var isShowingRestoreConfirmation = false

    private let backupService = BackupService()

    var body: some View {
        Form {
            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("backup.export.action", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImporting = true
                } label: {
                    Label("backup.import.action", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("backup.section.title")
            } footer: {
                Text("backup.section.footer")
            }

            Section("backup.currentData.title") {
                summaryRows(currentSummary)
            }
        }
        .navigationTitle("backup.title")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                notice = .exportSucceeded
            case .failure:
                notice = .exportFailed
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .sheet(item: $pendingBackup) { backup in
            NavigationStack {
                Form {
                    Section("backup.preview.file.title") {
                        LabeledContent("backup.preview.date") {
                            Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute())
                        }
                        LabeledContent("backup.preview.version", value: String(backup.formatVersion))
                    }

                    Section("backup.preview.contents.title") {
                        summaryRows(backup.summary)
                    }

                    Section {
                        Text("backup.preview.warning")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("backup.preview.title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") {
                            pendingBackup = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("backup.restore.action", role: .destructive) {
                            isShowingRestoreConfirmation = true
                        }
                    }
                }
                .confirmationDialog(
                    "backup.confirm.title",
                    isPresented: $isShowingRestoreConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("backup.confirm.overwrite", role: .destructive) {
                        restorePendingBackup()
                    }
                    Button("common.cancel", role: .cancel) {}
                } message: {
                    Text("backup.confirm.message")
                }
            }
        }
        .alert(
            notice?.titleKey ?? "backup.error.title",
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
                Text(notice.messageKey)
            }
        }
    }

    @ViewBuilder
    private func summaryRows(_ summary: BackupSummary) -> some View {
        LabeledContent("backup.summary.profiles", value: String(summary.profileCount))
        LabeledContent("backup.summary.transactions", value: String(summary.transactionCount))
        LabeledContent("backup.summary.incomes", value: String(summary.incomeCount))
        LabeledContent("backup.summary.fixedExpenses", value: String(summary.fixedExpenseCount))
        LabeledContent("backup.summary.savingsGoals", value: String(summary.savingsGoalCount))
    }

    private var currentSummary: BackupSummary {
        BackupSummary(
            createdAt: .now,
            formatVersion: SpendlyBackup.currentFormatVersion,
            profileCount: profiles.isEmpty ? 0 : 1,
            transactionCount: transactions.count,
            incomeCount: incomes.count,
            fixedExpenseCount: fixedExpenses.count,
            savingsGoalCount: savingsGoals.count
        )
    }

    private var defaultFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "SpendlyAI-backup-\(formatter.string(from: .now))"
    }

    private func prepareExport() {
        do {
            let backup = backupService.makeBackup(
                profile: profiles.first,
                transactions: transactions,
                incomes: incomes,
                fixedExpenses: fixedExpenses,
                savingsGoals: savingsGoals
            )
            exportDocument = BackupDocument(data: try backupService.encode(backup))
            isExporting = true
        } catch {
            notice = .exportFailed
        }
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                pendingBackup = try backupService.decodeAndValidate(data)
            } catch let error as BackupError {
                switch error {
                case .unsupportedVersion:
                    notice = .unsupportedVersion
                case .unreadableFile, .invalidData:
                    notice = .invalidFile
                }
            } catch {
                notice = .invalidFile
            }
        case .failure:
            notice = .importFailed
        }
    }

    private func restorePendingBackup() {
        guard let pendingBackup else { return }

        do {
            try backupService.restore(pendingBackup, in: modelContext)
            self.pendingBackup = nil
            notice = .restoreSucceeded
        } catch {
            notice = .restoreFailed
        }
    }
}

private enum BackupNotice {
    case exportSucceeded
    case exportFailed
    case importFailed
    case invalidFile
    case unsupportedVersion
    case restoreSucceeded
    case restoreFailed

    var titleKey: LocalizedStringKey {
        switch self {
        case .exportSucceeded:
            "backup.export.success.title"
        case .restoreSucceeded:
            "backup.restore.success.title"
        case .exportFailed, .importFailed, .invalidFile, .unsupportedVersion, .restoreFailed:
            "backup.error.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .exportSucceeded:
            "backup.export.success.message"
        case .exportFailed:
            "backup.export.failure.message"
        case .importFailed:
            "backup.import.failure.message"
        case .invalidFile:
            "backup.invalidFile.message"
        case .unsupportedVersion:
            "backup.unsupportedVersion.message"
        case .restoreSucceeded:
            "backup.restore.success.message"
        case .restoreFailed:
            "backup.restore.failure.message"
        }
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}
