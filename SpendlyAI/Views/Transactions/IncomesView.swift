import SwiftData
import SwiftUI

struct IncomesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]
    @Query private var profiles: [UserFinancialProfile]

    @State private var searchText = ""
    @State private var editorState: IncomeEditorState?

    private var visibleIncomes: [Income] {
        incomes
            .filter {
                searchText.isEmpty
                    || $0.incomeDescription.localizedStandardContains(searchText)
            }
            .sorted {
                ($0.dueDate ?? $0.date) > ($1.dueDate ?? $1.date)
            }
    }

    private var currencyCode: String {
        profiles.first?.currencyCode ?? "NOK"
    }

    var body: some View {
        List {
            if visibleIncomes.isEmpty {
                ContentUnavailableView(
                    "incomes.empty.title",
                    systemImage: "banknote",
                    description: Text(
                        searchText.isEmpty
                            ? "incomes.empty.message"
                            : "incomes.search.empty"
                    )
                )
            } else {
                ForEach(visibleIncomes) { income in
                    Button {
                        editorState = IncomeEditorState(income: income)
                    } label: {
                        IncomeRow(income: income, currencyCode: currencyCode)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("common.delete", role: .destructive) {
                            modelContext.delete(income)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle("incomes.title")
        .searchable(text: $searchText, prompt: "incomes.search")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorState = IncomeEditorState()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("income.add")
            }
        }
        .sheet(item: $editorState) { state in
            IncomeEditorView(income: state.income)
        }
    }
}

private struct IncomeRow: View {
    @Environment(\.locale) private var locale

    let income: Income
    let currencyCode: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: income.category.systemImage)
                .font(.headline)
                .foregroundStyle(AppStyle.accentColor)
                .frame(width: 32, height: 32)
                .background(AppStyle.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if income.incomeDescription.isEmpty {
                    Text("income.untitled")
                        .font(.body.weight(.medium))
                } else {
                    Text(verbatim: income.incomeDescription)
                        .font(.body.weight(.medium))
                }

                HStack(spacing: 6) {
                    Text(income.category.titleKey)
                    Text(income.dueDate ?? income.date, format: .dateTime.day().month().year())
                    if income.recurrence != .oneTime {
                        Text(income.recurrence.titleKey)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(income.effectivePaymentStatus().titleKey(for: .income))
                    .font(.caption)
                    .foregroundStyle(income.effectivePaymentStatus().displayColor)
            }

            Spacer()

            Text(MoneyFormatter.string(
                from: income.amount,
                currencyCode: currencyCode,
                locale: locale
            ))
                .font(.body.weight(.semibold))
                .foregroundStyle(AppStyle.accentColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct IncomeEditorState: Identifiable {
    let id = UUID()
    let income: Income?

    init(income: Income? = nil) {
        self.income = income
    }
}

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let income: Income?

    @State private var amount: String
    @State private var category: IncomeCategory
    @State private var incomeDescription: String
    @State private var notes: String
    @State private var recurrence: IncomeRecurrence
    @State private var isActive: Bool
    @State private var dueDate: Date
    @State private var settledDate: Date
    @State private var paymentStatus: PaymentStatus

    init(income: Income?) {
        self.income = income
        _amount = State(initialValue: income?.amount.description ?? "")
        _category = State(initialValue: income?.category ?? .salary)
        _incomeDescription = State(initialValue: income?.incomeDescription ?? "")
        _notes = State(initialValue: income?.notes ?? "")
        _recurrence = State(initialValue: income?.recurrence ?? .oneTime)
        _isActive = State(initialValue: income?.isActive ?? true)
        _dueDate = State(initialValue: income?.dueDate ?? income?.date ?? .now)
        _settledDate = State(initialValue: income?.settledDate ?? income?.date ?? .now)
        _paymentStatus = State(initialValue: income?.paymentStatus ?? .settled)
    }

    private var parsedAmount: Decimal? {
        MoneyParser.decimal(from: amount)
    }

    private var canSave: Bool {
        guard let parsedAmount else { return false }
        return parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("income.details") {
                    TextField("income.amount", text: $amount)
                        .keyboardType(.decimalPad)

                    DatePicker("payment.dueDate", selection: $dueDate, displayedComponents: .date)

                    Picker("payment.status", selection: $paymentStatus) {
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.titleKey(for: .income))
                                .tag(status)
                        }
                    }

                    if paymentStatus == .settled {
                        DatePicker("payment.receivedDate", selection: $settledDate, displayedComponents: .date)
                    }

                    Picker("income.category", selection: $category) {
                        ForEach(IncomeCategory.allCases, id: \.self) { category in
                            Text(category.titleKey)
                                .tag(category)
                        }
                    }

                    TextField(
                        "income.description",
                        text: $incomeDescription
                    )

                    Picker("income.recurrence", selection: $recurrence) {
                        ForEach(IncomeRecurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.titleKey)
                                .tag(recurrence)
                        }
                    }

                    if recurrence != .oneTime {
                        Toggle("income.active", isOn: $isActive)
                    }
                }

                Section("income.notes") {
                    TextField(
                        "income.notes.placeholder",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle(
                income == nil ? "income.add" : "income.edit"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let parsedAmount else { return }

        let trimmedDescription = incomeDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let income {
            income.amount = parsedAmount
            income.category = category
            income.incomeDescription = trimmedDescription
            income.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            income.recurrence = recurrence
            income.isActive = recurrence == .oneTime ? true : isActive
            income.dueDate = dueDate
            income.settledDate = paymentStatus == .settled ? settledDate : nil
            income.paymentStatus = paymentStatus
        } else {
            modelContext.insert(
                Income(
                    amount: parsedAmount,
                    date: .now,
                    category: category,
                    incomeDescription: trimmedDescription,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    recurrence: recurrence,
                    isActive: recurrence == .oneTime ? true : isActive,
                    dueDate: dueDate,
                    settledDate: paymentStatus == .settled ? settledDate : nil,
                    paymentStatus: paymentStatus
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        IncomesView()
    }
    .modelContainer(for: [
        UserFinancialProfile.self,
        FixedExpense.self,
        Transaction.self,
        Income.self,
        SavingsGoal.self,
        DailyBudgetSnapshot.self
    ], inMemory: true)
}
