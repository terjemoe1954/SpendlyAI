import Foundation
import PDFKit
import Testing
@testable import SpendlyAI

struct ReportPrivacyTests {
    @Test @MainActor
    func pdfContainsOnlyReportDataAndNoPersonalProfileFields() throws {
        let summary = ReportSummary(
            totalIncome: 30_000,
            totalVariableExpenses: 5_000,
            totalFixedExpenses: 10_000,
            plannedSavings: 2_000,
            entryCount: 4,
            variableExpenseCategories: [
                ReportSpendingCategoryTotal(category: .transport, amount: 5_000)
            ],
            fixedExpenseCategories: [
                ReportFixedExpenseCategoryTotal(category: .housing, amount: 10_000)
            ]
        )
        let request = ReportPDFRequest(
            appName: "Spendly AI",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_702_592_000),
            currencyCode: "NOK",
            generatedAt: Date(timeIntervalSince1970: 1_702_592_000),
            summary: summary
        )

        let data = ReportPDFGenerator().makePDF(
            for: request,
            locale: Locale(identifier: "nb_NO")
        )
        let document = try #require(PDFDocument(data: data))
        let text = try #require(document.string)

        #expect(text.contains("Spendly AI"))
        #expect(text.contains("NOK"))

        let personalFieldLabels = [
            "E-post",
            "Email",
            "Telefon",
            "Phone",
            "Notater",
            "Notes",
            "User ID",
            "Profile ID"
        ]
        for label in personalFieldLabels {
            #expect(!text.localizedCaseInsensitiveContains(label))
        }
    }
}
