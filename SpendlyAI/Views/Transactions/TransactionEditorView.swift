//
//  TransactionEditorView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let transaction: Transaction?

    @State private var amount: String
    @State private var category: SpendingCategory
    @State private var transactionDescription: String
    @State private var date: Date
    @State private var isEssential: Bool
    @State private var notes: String

    private var canSave: Bool {
        decimalValue(from: amount) != nil
    }

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        _amount = State(initialValue: transaction?.amount.description ?? "")
        _category = State(initialValue: transaction?.category ?? .other)
        _transactionDescription = State(initialValue: transaction?.transactionDescription ?? "")
        _date = State(initialValue: transaction?.date ?? .now)
        _isEssential = State(initialValue: transaction?.isEssential ?? false)
        _notes = State(initialValue: transaction?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("transaction.details") {
                    TextField("transaction.amount", text: $amount)
                        .keyboardType(.decimalPad)

                    Picker("transaction.category", selection: $category) {
                        ForEach(SpendingCategory.allCases, id: \.self) { category in
                            Text(category.titleKey)
                                .tag(category)
                        }
                    }

                    TextField("transaction.description", text: $transactionDescription)

                    DatePicker("transaction.dateTime", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Toggle("transaction.essential", isOn: $isEssential)
                }

                Section("transaction.notes") {
                    TextField("transaction.notes.placeholder", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(transaction == nil ? "transaction.new.title" : "transaction.edit.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("transaction.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("transaction.save") {
                        saveTransaction()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveTransaction() {
        guard let decimalAmount = decimalValue(from: amount) else { return }

        let trimmedDescription = transactionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transaction {
            transaction.amount = decimalAmount
            transaction.category = category
            transaction.transactionDescription = trimmedDescription
            transaction.date = date
            transaction.isEssential = isEssential
            transaction.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            modelContext.insert(Transaction(
                amount: decimalAmount,
                date: date,
                category: category,
                transactionDescription: trimmedDescription,
                isEssential: isEssential,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            ))
        }

        dismiss()
    }

    private func decimalValue(from text: String) -> Decimal? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalizedText)
    }
}

extension SpendingCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .food:
            "category.food"
        case .groceries:
            "category.groceries"
        case .transport:
            "category.transport"
        case .shopping:
            "category.shopping"
        case .entertainment:
            "category.entertainment"
        case .health:
            "category.health"
        case .bills:
            "category.bills"
        case .savings:
            "category.savings"
        case .other:
            "category.other"
        }
    }
}

#Preview {
    TransactionEditorView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
