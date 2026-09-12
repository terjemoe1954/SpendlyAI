//
//  GoalEditorView.swift
//  SpendlyAI
//

import SwiftData
import SwiftUI

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let goal: SavingsGoal?

    @State private var name: String
    @State private var targetAmount: String
    @State private var savedAmount: String
    @State private var targetDate: Date
    @State private var priority: GoalPriority

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && decimalValue(from: targetAmount) != nil
    }

    init(goal: SavingsGoal? = nil) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _targetAmount = State(initialValue: goal?.targetAmount.description ?? "")
        _savedAmount = State(initialValue: goal?.savedAmount.description ?? "")
        _targetDate = State(initialValue: goal?.targetDate ?? .now)
        _priority = State(initialValue: goal?.priority ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("goal.details") {
                    TextField("goal.name", text: $name)

                    TextField("goal.targetAmount", text: $targetAmount)
                        .keyboardType(.decimalPad)

                    TextField("goal.savedAmount", text: $savedAmount)
                        .keyboardType(.decimalPad)

                    DatePicker("goal.targetDate", selection: $targetDate, displayedComponents: .date)

                    Picker("goal.priority", selection: $priority) {
                        ForEach(GoalPriority.allCases, id: \.self) { priority in
                            Text(priority.titleKey)
                                .tag(priority)
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "goal.new.title" : "goal.edit.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("goal.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("goal.save") {
                        saveGoal()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveGoal() {
        guard let target = decimalValue(from: targetAmount) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = decimalValue(from: savedAmount) ?? 0
        let isCompleted = saved >= target

        if let goal {
            goal.name = trimmedName
            goal.targetAmount = target
            goal.savedAmount = saved
            goal.targetDate = targetDate
            goal.priority = priority
            goal.isCompleted = isCompleted
        } else {
            modelContext.insert(SavingsGoal(
                name: trimmedName,
                targetAmount: target,
                targetDate: targetDate,
                savedAmount: saved,
                priority: priority,
                isCompleted: isCompleted
            ))
        }

        dismiss()
    }

    private func decimalValue(from text: String) -> Decimal? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalizedText)
    }
}

extension GoalPriority {
    var titleKey: LocalizedStringKey {
        switch self {
        case .low:
            "goal.priority.low"
        case .medium:
            "goal.priority.medium"
        case .high:
            "goal.priority.high"
        }
    }
}

#Preview {
    GoalEditorView()
        .modelContainer(for: [
            UserFinancialProfile.self,
            FixedExpense.self,
            Transaction.self,
            SavingsGoal.self,
            DailyBudgetSnapshot.self
        ], inMemory: true)
}
