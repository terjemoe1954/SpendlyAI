import Foundation
import Testing
@testable import SpendlyAI

struct ReportCSVGeneratorTests {
    @Test func exportsTransactionsAndIncomesWithStableColumns() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-04T08:30:00Z"))
        let entries = [
            ReportCSVEntry(
                type: .expense,
                date: date,
                description: "Fuel",
                category: "transport",
                amount: Decimal(12_005) / Decimal(10),
                currencyCode: "NOK"
            ),
            ReportCSVEntry(
                type: .income,
                date: date,
                description: "Salary",
                category: "salary",
                amount: Decimal(30_000),
                currencyCode: "NOK"
            )
        ]

        let data = ReportCSVGenerator().makeCSV(entries: entries)
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.hasPrefix("type,date,description,category,amount,currency\r\n"))
        #expect(csv.contains("expense,2026-10-04T08:30:00Z,Fuel,transport,1200.5,NOK"))
        #expect(csv.contains("income,2026-10-04T08:30:00Z,Salary,salary,30000,NOK"))
    }

    @Test func escapesCommasQuotesAndLineBreaks() throws {
        let entry = ReportCSVEntry(
            type: .expense,
            date: Date(timeIntervalSince1970: 0),
            description: "Coffee, \"large\"\nreceipt",
            category: "other",
            amount: Decimal(125) / Decimal(10),
            currencyCode: "NOK"
        )

        let data = ReportCSVGenerator().makeCSV(entries: [entry])
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.contains("\"Coffee, \"\"large\"\"\nreceipt\""))
    }

    @Test func emptyExportContainsOnlyHeader() throws {
        let data = ReportCSVGenerator().makeCSV(entries: [])
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv == "type,date,description,category,amount,currency\r\n")
    }

    @Test func exportOmitsPrivateAndInternalFields() throws {
        let entry = ReportCSVEntry(
            type: .income,
            date: Date(timeIntervalSince1970: 0),
            description: "Consulting",
            category: "freelance",
            amount: 500,
            currencyCode: "NOK"
        )

        let data = ReportCSVGenerator().makeCSV(entries: [entry])
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(!csv.contains("notes"))
        #expect(!csv.contains("profile"))
        #expect(!csv.contains("id"))
    }
}
