import Foundation
import Testing
@testable import SpendlyAI

struct MySavingsImportServiceTests {
    @Test func decodesAndMapsMySavingsTransactions() throws {
        let json = """
        {
          "formatVersion": 4,
          "exportedAt": "2026-10-21T07:27:26Z",
          "categories": [
            {"id": "dining", "name": "Spise Ute", "icon": "person"},
            {"id": "income", "name": "Lønn & Inntekt", "icon": "person"}
          ],
          "transactions": [
            {
              "amount": "249.50",
              "category": "dining",
              "createdAt": "2026-10-19T10:00:00Z",
              "dueDate": "2026-10-19T10:00:00Z",
              "id": "expense-1",
              "isArchived": false,
              "isCompleted": true,
              "notes": "Middag",
              "paidDate": "2026-10-19T10:00:00Z",
              "recurrence": "none",
              "status": "paid",
              "title": "Restaurant",
              "type": "expense",
              "updatedAt": "2026-10-19T10:00:00Z"
            },
            {
              "amount": "42000",
              "category": "income",
              "createdAt": "2026-10-20T10:00:00Z",
              "dueDate": "2026-10-20T10:00:00Z",
              "id": "income-1",
              "isArchived": false,
              "isCompleted": false,
              "notes": "",
              "recurrence": "monthly",
              "status": "pending",
              "title": "Lønn",
              "type": "income",
              "updatedAt": "2026-10-20T10:00:00Z"
            }
          ],
          "budgets": [],
          "settings": {}
        }
        """

        let plan = try MySavingsImportService().decode(Data(json.utf8))

        #expect(plan.expenses.count == 1)
        #expect(plan.incomes.count == 1)
        #expect(plan.expenses[0].category == .diningOut)
        #expect(plan.expenses[0].paymentStatus == .settled)
        #expect(plan.incomes[0].category == .income)
        #expect(plan.incomes[0].recurrence == .monthly)
        #expect(plan.incomes[0].paymentStatus == .pending)
    }

    @Test func preservesUnknownCategoryInNotes() throws {
        let json = """
        {
          "formatVersion": 4,
          "exportedAt": "2026-10-21T07:27:26Z",
          "categories": [{"id": "custom", "name": "Hund", "icon": "pawprint"}],
          "transactions": [{
            "amount": "100",
            "category": "custom",
            "createdAt": "2026-10-19T10:00:00Z",
            "dueDate": "2026-10-19T10:00:00Z",
            "id": "expense-1",
            "isArchived": false,
            "isCompleted": true,
            "notes": "Veterinær",
            "paidDate": "2026-10-19T10:00:00Z",
            "recurrence": "none",
            "status": "paid",
            "title": "Kontroll",
            "type": "expense",
            "updatedAt": "2026-10-19T10:00:00Z"
          }],
          "budgets": [],
          "settings": {}
        }
        """

        let plan = try MySavingsImportService().decode(Data(json.utf8))

        #expect(plan.expenses[0].category == .other)
        #expect(plan.expenses[0].notes?.contains("Hund") == true)
        #expect(plan.expenses[0].notes?.contains("Veterinær") == true)
    }

    @Test func importsUpcomingRecurringExpenseAsFixedExpenseOnly() throws {
        let json = """
        {
          "formatVersion": 4,
          "exportedAt": "2026-10-21T07:27:26Z",
          "categories": [{"id": "home", "name": "Bolig & Strøm", "icon": "house"}],
          "transactions": [{
            "amount": "11703",
            "category": "home",
            "createdAt": "2026-10-20T08:04:00Z",
            "dueDate": "2026-11-20T09:04:00Z",
            "id": "expense-1",
            "isArchived": false,
            "isCompleted": false,
            "notes": "",
            "recurrence": "monthly",
            "recurrenceAnchorDay": 20,
            "recurrenceSeriesID": "series-1",
            "status": "pending",
            "title": "Copy of Husleie",
            "type": "expense",
            "updatedAt": "2026-10-20T08:04:00Z"
          }],
          "budgets": [],
          "settings": {}
        }
        """

        let plan = try MySavingsImportService().decode(Data(json.utf8))

        #expect(plan.expenses.isEmpty)
        #expect(plan.fixedExpenses.count == 1)
        #expect(plan.fixedExpenses[0].name == "Husleie")
        #expect(plan.fixedExpenses[0].category == .housing)
        #expect(plan.fixedExpenses[0].recurrence == .monthly)
        #expect(plan.fixedExpenses[0].dueDay == 20)
    }

    @Test func rejectsUnsupportedFormatVersion() {
        let json = """
        {
          "formatVersion": 3,
          "exportedAt": "2026-10-21T07:27:26Z",
          "categories": [],
          "transactions": []
        }
        """

        #expect(throws: MySavingsImportError.unsupportedVersion(3)) {
            try MySavingsImportService().decode(Data(json.utf8))
        }
    }
}
