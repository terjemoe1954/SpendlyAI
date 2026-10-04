import CoreTransferable
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ReportPDFPreview: Identifiable {
    let id = UUID()
    let data: Data

    var shareDocument: ReportPDFShareDocument {
        ReportPDFShareDocument(data: data)
    }
}

struct ReportPDFShareDocument: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            let directory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let fileURL = directory.appending(path: "SpendlyAI-report.pdf")
            try document.data.write(to: fileURL, options: .atomic)
            return SentTransferredFile(fileURL)
        }
    }
}

struct ReportPDFPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let preview: ReportPDFPreview

    var body: some View {
        NavigationStack {
            ReportPDFDocumentView(data: preview.data)
                .navigationTitle("Preview PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: preview.shareDocument,
                            preview: SharePreview("SpendlyAI report")
                        ) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct ReportPDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard pdfView.document == nil else {
            return
        }

        pdfView.document = PDFDocument(data: data)
    }
}
