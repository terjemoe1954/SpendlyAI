//
//  TransactionsView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var showsNewTransaction = false
    @State private var selectedTransaction: Transaction?
    @State private var selectedCategory: SpendingCategory?

    private var filteredTransactions: [Transaction] {
        guard let selectedCategory else { return transactions }
        return transactions.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView(
                        "transactions.empty.title",
                        systemImage: "list.bullet.rectangle",
                        description: Text("transactions.empty.message")
                    )
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                TransactionRowView(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("tab.transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("transactions.filter.all") {
                            selectedCategory = nil
                        }

                        ForEach(SpendingCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.titleKey)
                            }
                        }
                    } label: {
                        Label("transactions.filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsNewTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("transaction.new.title")
                }
            }
            .sheet(isPresented: $showsNewTransaction) {
                TransactionEditorView()
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction)
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(filteredTransactions[offset])
        }
    }
}

private struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: transaction.category.systemImage)
                .font(.headline)
                .foregroundStyle(AppStyle.accentColor)
                .frame(width: 32, height: 32)
                .background(AppStyle.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if transaction.transactionDescription.isEmpty {
                    Text("transaction.untitled")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text(verbatim: transaction.transactionDescription)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 6) {
                    Text(transaction.category.titleKey)
                    Text(transaction.date, format: .dateTime.day().month().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "NOK"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: transaction.amount as NSDecimalNumber) ?? transaction.amount.description
    }
}

private extension SpendingCategory {
    var systemImage: String {
        switch self {
        case .food:
            "fork.knife"
        case .groceries:
            "basket"
        case .transport:
            "car"
        case .shopping:
            "bag"
        case .entertainment:
            "ticket"
        case .health:
            "cross.case"
        case .bills:
            "doc.text"
        case .savings:
            "banknote"
        case .other:
            "circle.grid.2x2"
        }
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
