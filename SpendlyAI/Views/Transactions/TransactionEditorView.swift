//
//  TransactionEditorView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var existingTransactions: [Transaction]

    private let transaction: Transaction?

    @State private var amount: String
    @State private var category: SpendingCategory
    @State private var transactionDescription: String
    @State private var dueDate: Date
    @State private var settledDate: Date
    @State private var paymentStatus: PaymentStatus
    @State private var notes: String
    @State private var hasSelectedCategoryManually: Bool
    @State private var suggestedCategory: SpendingCategory?
    @State private var activeDatePicker: TransactionDatePicker?

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
        _suggestedCategory = State(initialValue: nil)
        _activeDatePicker = State(initialValue: nil)
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

                    dateButton(
                        titleKey: "payment.dueDate",
                        date: dueDate,
                        picker: .due
                    )

                    Picker("payment.status", selection: $paymentStatus) {
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.titleKey(for: .expense))
                                .tag(status)
                        }
                    }
                    .pickerStyle(.menu)

                    if paymentStatus == .settled || paymentStatus == .withdrawn {
                        dateButton(
                            titleKey: "payment.paidDate",
                            date: settledDate,
                            picker: .settled
                        )
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
            .sheet(item: $activeDatePicker) { picker in
                datePickerSheet(for: picker)
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(SpendingCategory.allCases, id: \.self) { option in
                Button {
                    category = option
                    suggestedCategory = nil
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
                HStack(spacing: 6) {
                    if suggestedCategory == category {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppStyle.accentColor)
                            .accessibilityHidden(true)
                    }
                    Text(category.titleKey)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func applySuggestedCategory(for description: String) {
        guard transaction == nil, !hasSelectedCategoryManually else { return }

        let suggestion = CategorySuggestionService.suggestion(
            for: description,
            history: existingTransactions
        )
        suggestedCategory = suggestion
        category = suggestion ?? .other
    }

    private func dateButton(
        titleKey: LocalizedStringKey,
        date: Date,
        picker: TransactionDatePicker
    ) -> some View {
        Button {
            activeDatePicker = picker
        } label: {
            LabeledContent(titleKey) {
                Text(date, format: .dateTime.day().month().year())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func datePickerSheet(for picker: TransactionDatePicker) -> some View {
        NavigationStack {
            DatePicker(
                picker.titleKey,
                selection: dateBinding(for: picker),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .onChange(of: selectedDate(for: picker)) { oldValue, newValue in
                guard !Calendar.current.isDate(oldValue, inSameDayAs: newValue) else { return }
                activeDatePicker = nil
            }
            .navigationTitle(picker.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        activeDatePicker = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func dateBinding(for picker: TransactionDatePicker) -> Binding<Date> {
        Binding(
            get: { selectedDate(for: picker) },
            set: { newValue in
                switch picker {
                case .due:
                    dueDate = newValue
                case .settled:
                    settledDate = newValue
                }
            }
        )
    }

    private func selectedDate(for picker: TransactionDatePicker) -> Date {
        switch picker {
        case .due: dueDate
        case .settled: settledDate
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

private enum TransactionDatePicker: String, Identifiable {
    case due
    case settled

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .due: "payment.dueDate"
        case .settled: "payment.paidDate"
        }
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
        (.refund, [
            "refusjon", "tilbakebetaling", "refundert", "refund", "reimbursement", "repaid"
        ]),
        (.insurance, ["forsikring"]),
        (.gifts, ["gave", "blomster"]),
        (.gambling, ["norsk tipping", "lotto", "oddsen"]),
        (.withdrawals, ["restskatt", "skatt", "avgift"])
    ]

    static func suggestion(
        for description: String,
        history: [Transaction]
    ) -> SpendingCategory? {
        let normalized = normalize(description)
        guard normalized.count >= 3 else { return nil }

        if let ruleMatch = rules.first(where: { _, keywords in
            keywords.contains { keyword in
                normalized.contains(normalize(keyword))
            }
        }) {
            return ruleMatch.0
        }

        return history.first(where: { transaction in
            let previousDescription = normalize(transaction.transactionDescription)
            guard previousDescription.count >= 3 else { return false }
            return previousDescription == normalized
                || previousDescription.contains(normalized)
                || normalized.contains(previousDescription)
        })?.category
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        case .refund: "incomeCategory.refund"
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
