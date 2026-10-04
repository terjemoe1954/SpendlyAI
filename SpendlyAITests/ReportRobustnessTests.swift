import Foundation
import PDFKit
import Testing
@testable import SpendlyAI

struct ReportRobustnessTests {
    @Test @MainActor
    func emptyPeriodCreatesReadableSinglePagePDF() throws {
        let data = makePDF(summary: emptySummary(), currencyCode: "NOK")
        let document = try #require(PDFDocument(data: data))
        let text = try #require(document.string)

        #expect(document.pageCount == 1)
        #expect(text.contains("NOK"))
        #expect(text.contains("0"))
    }

    @Test
    func largeCSVExportKeepsEveryEntry() throws {
        let entryCount = 5_000
        let entries = (0..<entryCount).map { index in
            ReportCSVEntry(
                type: index.isMultiple(of: 2) ? .expense : .income,
                date: Date(timeIntervalSince1970: TimeInterval(index)),
                description: "Entry \(index)",
                category: "other",
                amount: Decimal(index) / 100,
                currencyCode: "NOK"
            )
        }

        let data = ReportCSVGenerator().makeCSV(entries: entries)
        let csv = try #require(String(data: data, encoding: .utf8))
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        #expect(lines.count == entryCount + 1)
        #expect(csv.contains("Entry 0"))
        #expect(csv.contains("Entry 4999"))
    }

    @Test @MainActor
    func pdfSupportsMultipleCurrencies() throws {
        for currencyCode in ["NOK", "USD", "THB"] {
            let summary = ReportSummary(
                totalIncome: Decimal(string: "1234.56") ?? 0,
                totalVariableExpenses: 0,
                totalFixedExpenses: 0,
                plannedSavings: 0,
                entryCount: 1,
                variableExpenseCategories: [],
                fixedExpenseCategories: []
            )
            let data = makePDF(summary: summary, currencyCode: currencyCode)
            let document = try #require(PDFDocument(data: data))
            let text = try #require(document.string)

            #expect(text.contains(currencyCode))
            #expect(document.pageCount == 1)
        }
    }

    @Test @MainActor
    func longCategoryReportCreatesReadablePageBreaks() throws {
        let summary = ReportSummary(
            totalIncome: 100_000,
            totalVariableExpenses: 10_000,
            totalFixedExpenses: 20_000,
            plannedSavings: 5_000,
            entryCount: 2_000,
            variableExpenseCategories: SpendingCategory.allCases.map {
                ReportSpendingCategoryTotal(category: $0, amount: 100)
            },
            fixedExpenseCategories: ExpenseCategory.allCases.map {
                ReportFixedExpenseCategoryTotal(category: $0, amount: 200)
            }
        )

        let data = makePDF(summary: summary, currencyCode: "NOK")
        let document = try #require(PDFDocument(data: data))

        #expect(document.pageCount > 1)
        for pageIndex in 0..<document.pageCount {
            let page = try #require(document.page(at: pageIndex))
            let text = try #require(page.string)
            #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(text.contains(String(pageIndex + 1)))
        }
    }

    private func emptySummary() -> ReportSummary {
        ReportSummary(
            totalIncome: 0,
            totalVariableExpenses: 0,
            totalFixedExpenses: 0,
            plannedSavings: 0,
            entryCount: 0,
            variableExpenseCategories: [],
            fixedExpenseCategories: []
        )
    }

    @MainActor
    private func makePDF(summary: ReportSummary, currencyCode: String) -> Data {
        let request = ReportPDFRequest(
            appName: "Spendly AI",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_702_592_000),
            currencyCode: currencyCode,
            generatedAt: Date(timeIntervalSince1970: 1_702_592_000),
            summary: summary
        )
        return ReportPDFGenerator().makePDF(
            for: request,
            locale: Locale(identifier: "nb_NO")
        )
    }
}
