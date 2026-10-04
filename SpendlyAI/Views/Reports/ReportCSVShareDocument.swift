import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ReportCSVShareDocument: Transferable, Sendable {
    let entries: [ReportCSVEntry]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("SpendlyAI-transactions")
                .appendingPathExtension("csv")
            let data = ReportCSVGenerator().makeCSV(entries: document.entries)
            try data.write(to: fileURL, options: .atomic)
            return SentTransferredFile(fileURL)
        }
    }
}
