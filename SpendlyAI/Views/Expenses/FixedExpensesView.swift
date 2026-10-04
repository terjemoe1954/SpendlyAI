import SwiftData
import SwiftUI

struct FixedExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedExpense.name) private var expenses: [FixedExpense]
    @Query private var profiles: [UserFinancialProfile]

    @State private var searchText = ""
    @State private var statusFilter: FixedExpenseStatusFilter = .all
    @State private var categoryFilter: ExpenseCategory?
    @State private var recurrenceFilter: ExpenseRecurrence?
    @State private var sortOption: FixedExpenseSortOption = .name
    @State private var editorState: FixedExpenseEditorState?

    private var visibleExpenses: [FixedExpense] {
        expenses
            .filter(matchesFilters)
            .sorted(by: sortOption.areInIncreasingOrder)
    }

    private var hasActiveFilters: Bool {
        statusFilter != .all || categoryFilter != nil || recurrenceFilter != nil
    }

    private var currencyCode: String {
        profiles.first?.currencyCode ?? "NOK"
    }

    var body: some View {
        List {
            if visibleExpenses.isEmpty {
                ContentUnavailableView(
                    "fixedExpenses.empty.title",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(
                        searchText.isEmpty && !hasActiveFilters
                            ? "fixedExpenses.empty.message"
                            : "fixedExpenses.search.empty"
                    )
                )
            } else {
                ForEach(visibleExpenses) { expense in
                    Button {
                        editorState = FixedExpenseEditorState(expense: expense)
                    } label: {
                        FixedExpenseRow(expense: expense, currencyCode: currencyCode)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("common.delete", role: .destructive) {
                            modelContext.delete(expense)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle("fixedExpenses.title")
        .searchable(text: $searchText, prompt: "fixedExpenses.search")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                FixedExpenseOptionsMenu(
                    statusFilter: $statusFilter,
                    categoryFilter: $categoryFilter,
                    recurrenceFilter: $recurrenceFilter,
                    sortOption: $sortOption,
                    hasActiveFilters: hasActiveFilters,
                    resetFilters: resetFilters
                )

                Button {
                    editorState = FixedExpenseEditorState()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("fixedExpenses.add")
            }
        }
        .sheet(item: $editorState) { state in
            FixedExpenseEditorView(expense: state.expense)
        }
    }

    private func matchesFilters(_ expense: FixedExpense) -> Bool {
        let matchesSearch = searchText.isEmpty
            || expense.name.localizedStandardContains(searchText)
        let matchesStatus = statusFilter.includes(expense)
        let matchesCategory = categoryFilter == nil || expense.category == categoryFilter
        let matchesRecurrence = recurrenceFilter == nil || expense.recurrence == recurrenceFilter

        return matchesSearch && matchesStatus && matchesCategory && matchesRecurrence
    }

    private func resetFilters() {
        statusFilter = .all
        categoryFilter = nil
        recurrenceFilter = nil
    }
}

private struct FixedExpenseOptionsMenu: View {
    @Binding var statusFilter: FixedExpenseStatusFilter
    @Binding var categoryFilter: ExpenseCategory?
    @Binding var recurrenceFilter: ExpenseRecurrence?
    @Binding var sortOption: FixedExpenseSortOption

    let hasActiveFilters: Bool
    let resetFilters: () -> Void

    var body: some View {
        Menu {
            Menu("fixedExpenses.filter.status") {
                ForEach(FixedExpenseStatusFilter.allCases) { filter in
                    Button {
                        statusFilter = filter
                    } label: {
                        MenuSelectionLabel(
                            titleKey: filter.titleKey,
                            isSelected: statusFilter == filter
                        )
                    }
                }
            }

            Menu("fixedExpenses.filter.category") {
                Button {
                    categoryFilter = nil
                } label: {
                    MenuSelectionLabel(
                        titleKey: "fixedExpenses.filter.allCategories",
                        isSelected: categoryFilter == nil
                    )
                }

                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Button {
                        categoryFilter = category
                    } label: {
                        MenuSelectionLabel(
                            titleKey: category.titleKey,
                            isSelected: categoryFilter == category
                        )
                    }
                }
            }

            Menu("fixedExpenses.filter.recurrence") {
                Button {
                    recurrenceFilter = nil
                } label: {
                    MenuSelectionLabel(
                        titleKey: "fixedExpenses.filter.allRecurrences",
                        isSelected: recurrenceFilter == nil
                    )
                }

                ForEach(ExpenseRecurrence.allCases, id: \.self) { recurrence in
                    Button {
                        recurrenceFilter = recurrence
                    } label: {
                        MenuSelectionLabel(
                            titleKey: recurrence.titleKey,
                            isSelected: recurrenceFilter == recurrence
                        )
                    }
                }
            }

            Menu("fixedExpenses.sort.title") {
                ForEach(FixedExpenseSortOption.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        MenuSelectionLabel(
                            titleKey: option.titleKey,
                            isSelected: sortOption == option
                        )
                    }
                }
            }

            if hasActiveFilters {
                Divider()

                Button("fixedExpenses.filter.reset", action: resetFilters)
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("fixedExpenses.filterAndSort")
    }
}

private struct MenuSelectionLabel: View {
    let titleKey: LocalizedStringKey
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(titleKey)

            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

private enum FixedExpenseStatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case inactive

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "fixedExpenses.filter.allStatuses"
        case .active: "fixedExpenses.active"
        case .inactive: "fixedExpenses.inactive"
        }
    }

    func includes(_ expense: FixedExpense) -> Bool {
        switch self {
        case .all: true
        case .active: expense.isActive
        case .inactive: !expense.isActive
        }
    }
}

private enum FixedExpenseSortOption: String, CaseIterable, Identifiable {
    case name
    case amountDescending
    case dueDay

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .name: "fixedExpenses.sort.name"
        case .amountDescending: "fixedExpenses.sort.amountDescending"
        case .dueDay: "fixedExpenses.sort.dueDay"
        }
    }

    func areInIncreasingOrder(_ lhs: FixedExpense, _ rhs: FixedExpense) -> Bool {
        switch self {
        case .name:
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .amountDescending:
            if lhs.amount == rhs.amount {
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            } else {
                lhs.amount > rhs.amount
            }
        case .dueDay:
            if lhs.dueDay == rhs.dueDay {
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            } else {
                lhs.dueDay < rhs.dueDay
            }
        }
    }
}

private struct FixedExpenseRow: View {
    let expense: FixedExpense
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.headline)

                Text("fixedExpenses.dueDay \(expense.dueDay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(expense.category.titleKey)
                    Text("·")
                    Text(expense.recurrence.titleKey)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount, format: .currency(code: currencyCode))
                    .font(.body.weight(.semibold))

                Text(expense.isActive ? "fixedExpenses.active" : "fixedExpenses.inactive")
                    .font(.caption)
                    .foregroundStyle(expense.isActive ? Color.secondary : Color.orange)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct FixedExpenseEditorState: Identifiable {
    let id = UUID()
    let expense: FixedExpense?

    init(expense: FixedExpense? = nil) {
        self.expense = expense
    }
}

private struct FixedExpenseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: FixedExpense?

    @State private var name: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var category: ExpenseCategory
    @State private var recurrence: ExpenseRecurrence
    @State private var isActive: Bool

    init(expense: FixedExpense?) {
        self.expense = expense
        _name = State(initialValue: expense?.name ?? "")
        _amount = State(initialValue: expense?.amount.description ?? "")
        _dueDate = State(initialValue: Self.date(for: expense?.dueDay ?? Calendar.current.component(.day, from: .now)))
        _category = State(initialValue: expense?.category ?? .other)
        _recurrence = State(initialValue: expense?.recurrence ?? .monthly)
        _isActive = State(initialValue: expense?.isActive ?? true)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("onboarding.expense.name", text: $name)
                    TextField("onboarding.expense.amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("onboarding.expense.dueDate", selection: $dueDate, displayedComponents: .date)

                    Picker("fixedExpenses.category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Text(category.titleKey)
                                .tag(category)
                        }
                    }

                    Picker("fixedExpenses.recurrence", selection: $recurrence) {
                        ForEach(ExpenseRecurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.titleKey)
                                .tag(recurrence)
                        }
                    }

                    Toggle("fixedExpenses.active", isOn: $isActive)
                }
            }
            .navigationTitle(expense == nil ? "fixedExpenses.add" : "fixedExpenses.edit")
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

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDay = Calendar.current.component(.day, from: dueDate)

        if let expense {
            expense.name = trimmedName
            expense.amount = parsedAmount
            expense.dueDay = dueDay
            expense.category = category
            expense.recurrence = recurrence
            expense.isActive = isActive
        } else {
            modelContext.insert(FixedExpense(
                name: trimmedName,
                amount: parsedAmount,
                dueDay: dueDay,
                category: category,
                recurrence: recurrence,
                isActive: isActive
            ))
        }

        try? modelContext.save()
        dismiss()
    }

    private static func date(for day: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: .now)
        components.day = min(max(day, 1), 28)
        return Calendar.current.date(from: components) ?? .now
    }
}

private extension ExpenseCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .housing: "expenseCategory.housing"
        case .utilities: "expenseCategory.utilities"
        case .insurance: "expenseCategory.insurance"
        case .transport: "expenseCategory.transport"
        case .subscriptions: "expenseCategory.subscriptions"
        case .debt: "expenseCategory.debt"
        case .childcare: "expenseCategory.childcare"
        case .groceries: "expenseCategory.groceries"
        case .health: "expenseCategory.health"
        case .other: "expenseCategory.other"
        }
    }
}

private extension ExpenseRecurrence {
    var titleKey: LocalizedStringKey {
        switch self {
        case .weekly: "expenseRecurrence.weekly"
        case .biweekly: "expenseRecurrence.biweekly"
        case .monthly: "expenseRecurrence.monthly"
        case .quarterly: "expenseRecurrence.quarterly"
        case .yearly: "expenseRecurrence.yearly"
        }
    }
}

#Preview {
    NavigationStack {
        FixedExpensesView()
    }
    .modelContainer(for: [
        UserFinancialProfile.self,
        FixedExpense.self,
        Transaction.self,
        SavingsGoal.self,
        DailyBudgetSnapshot.self
    ], inMemory: true)
}
