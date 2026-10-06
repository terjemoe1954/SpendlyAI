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
    @State private var dueDate: Date
    @State private var settledDate: Date
    @State private var paymentStatus: PaymentStatus
    @State private var notes: String

    private var canSave: Bool {
        decimalValue(from: amount) != nil
    }

    init(transaction: Transaction? = nil) {
        self.transaction = transaction
        _amount = State(initialValue: transaction?.amount.description ?? "")
        _category = State(initialValue: transaction?.category ?? .other)
        _transactionDescription = State(initialValue: transaction?.transactionDescription ?? "")
        _dueDate = State(initialValue: transaction?.dueDate ?? transaction?.date ?? .now)
        _settledDate = State(initialValue: transaction?.settledDate ?? transaction?.date ?? .now)
        _paymentStatus = State(initialValue: transaction?.paymentStatus ?? .settled)
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

                    DatePicker("payment.dueDate", selection: $dueDate, displayedComponents: .date)

                    Picker("payment.status", selection: $paymentStatus) {
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.titleKey(for: .expense))
                                .tag(status)
                        }
                    }

                    if paymentStatus == .settled || paymentStatus == .withdrawn {
                        DatePicker("payment.paidDate", selection: $settledDate, displayedComponents: .date)
                    }
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
            transaction.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            transaction.dueDate = dueDate
            transaction.settledDate = paymentStatus == .settled || paymentStatus == .withdrawn ? settledDate : nil
            transaction.paymentStatus = paymentStatus
        } else {
            modelContext.insert(Transaction(
                amount: decimalAmount,
                date: .now,
                category: category,
                transactionDescription: trimmedDescription,
                isEssential: false,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                dueDate: dueDate,
                settledDate: paymentStatus == .settled || paymentStatus == .withdrawn ? settledDate : nil,
                paymentStatus: paymentStatus
            ))
        }

        dismiss()
    }

    private func decimalValue(from text: String) -> Decimal? {
        MoneyParser.decimal(from: text)
    }
}

extension SpendingCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .subscriptions: "expenseCategory.subscriptions"
        case .other: "category.other"
        case .groceries: "category.groceries"
        case .insurance: "expenseCategory.insurance"
        case .gifts: "category.gifts"
        case .health: "category.health"
        case .home: "category.home"
        case .income: "category.income"
        case .clothing: "category.clothing"
        case .communication: "category.communication"
        case .gambling: "category.gambling"
        case .savings: "category.savings"
        case .transport: "category.transport"
        case .withdrawals: "category.withdrawals"
        case .entertainment: "category.entertainment"
        case .developer: "category.developer"
        case .food: "category.food"
        case .shopping: "category.shopping"
        case .bills: "category.bills"
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
