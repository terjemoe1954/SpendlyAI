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
    @State private var hasSelectedCategoryManually: Bool

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
        _hasSelectedCategoryManually = State(initialValue: transaction != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("transaction.details") {
                    TextField("transaction.description", text: $transactionDescription)
                        .onChange(of: transactionDescription) { _, newValue in
                            applySuggestedCategory(for: newValue)
                        }

                    categoryMenu

                    TextField("transaction.amount", text: $amount)
                        .keyboardType(.decimalPad)

                    DatePicker(
                        "payment.dueDate",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    Picker("payment.status", selection: $paymentStatus) {
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.titleKey(for: .expense))
                                .tag(status)
                        }
                    }
                    .pickerStyle(.menu)

                    if paymentStatus == .settled || paymentStatus == .withdrawn {
                        DatePicker(
                            "payment.paidDate",
                            selection: $settledDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
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

    private var categoryMenu: some View {
        Menu {
            ForEach(SpendingCategory.allCases, id: \.self) { option in
                Button {
                    category = option
                    hasSelectedCategoryManually = true
                } label: {
                    if option == category {
                        Label(option.titleKey, systemImage: "checkmark")
                    } else {
                        Text(option.titleKey)
                    }
                }
            }
        } label: {
            LabeledContent("transaction.category") {
                Text(category.titleKey)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    private func applySuggestedCategory(for description: String) {
        guard transaction == nil,
              !hasSelectedCategoryManually,
              let suggestion = CategorySuggestionService.suggestion(for: description) else {
            return
        }
        category = suggestion
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

private enum CategorySuggestionService {
    private static let rules: [(SpendingCategory, [String])] = [
        (.diningOut, [
            "burger king", "mcdonald", "restaurant", "resturant", "kafé", "kafe",
            "café", "takeaway", "pizza", "sushi", "hamburger", "gatekjøkken"
        ]),
        (.groceries, [
            "kiwi", "rema", "coop", "meny", "joker", "bunnpris", "spar",
            "extra", "matbutikk", "dagligvare"
        ]),
        (.communication, [
            "telenor", "telia", "ice", "onecall", "talkmore", "mobil",
            "bredbånd", "bredband", "internett", "internet"
        ]),
        (.transport, [
            "ruter", "vy", "taxi", "uber", "buss", "tog", "parkering",
            "bompenger", "circle k", "esso", "bensin", "diesel"
        ]),
        (.developer, [
            "chatgpt", "openai", "apple developer", "app store connect",
            "github", "xcode", "hosting", "domene"
        ]),
        (.health, [
            "apotek", "lege", "tannlege", "brille", "optiker", "medisin"
        ]),
        (.home, [
            "husleie", "boliglån", "boliglan", "strøm", "strom",
            "elektrisitet", "fjernvarme"
        ]),
        (.clothing, [
            "klær", "klaer", "sko", "zalando", "hm.com", "dressmann"
        ]),
        (.entertainment, [
            "kino", "konsert", "hotell", "ferie", "flybillett", "museum"
        ]),
        (.subscriptions, [
            "netflix", "spotify", "hbo", "disney+", "abonnement"
        ]),
        (.insurance, ["forsikring"]),
        (.gifts, ["gave", "blomster"]),
        (.gambling, ["norsk tipping", "lotto", "oddsen"]),
        (.withdrawals, ["restskatt", "skatt", "avgift"])
    ]

    static func suggestion(for description: String) -> SpendingCategory? {
        let normalized = description
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count >= 3 else { return nil }

        return rules.first { _, keywords in
            keywords.contains { keyword in
                let normalizedKeyword = keyword.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
                return normalized.contains(normalizedKeyword)
            }
        }?.0
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
        case .diningOut: "category.diningOut"
        case .balanceAdjustment: "category.balanceAdjustment"
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
