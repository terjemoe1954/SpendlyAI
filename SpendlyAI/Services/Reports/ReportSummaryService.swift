import Foundation

struct ReportSummary: Equatable {
    let totalIncome: Decimal
    let totalVariableExpenses: Decimal
    let totalFixedExpenses: Decimal
    let plannedSavings: Decimal
    let entryCount: Int
    let variableExpenseCategories: [ReportSpendingCategoryTotal]
    let fixedExpenseCategories: [ReportFixedExpenseCategoryTotal]

    var netResult: Decimal {
        totalIncome - totalVariableExpenses - totalFixedExpenses - plannedSavings
    }
}

struct ReportSpendingCategoryTotal: Equatable {
    let category: SpendingCategory
    let amount: Decimal
}

struct ReportFixedExpenseCategoryTotal: Equatable {
    let category: ExpenseCategory
    let amount: Decimal
}

private struct FixedExpenseReportSummary {
    var total = Decimal.zero
    var occurrenceCount = 0
    var categoryTotals: [ExpenseCategory: Decimal] = [:]
}

struct ReportSummaryService {
    func makeSummary(
        transactions: [Transaction],
        incomes: [Income],
        fixedExpenses: [FixedExpense] = [],
        savingsGoals: [SavingsGoal] = [],
        profile: UserFinancialProfile? = nil,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> ReportSummary {
        let lowerBound = calendar.startOfDay(for: min(startDate, endDate))
        let endDay = calendar.startOfDay(for: max(startDate, endDate))
        let upperBound = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay

        let matchingTransactions = transactions.filter {
            $0.date >= lowerBound && $0.date < upperBound
        }
        let matchingIncomes = incomes.filter {
            $0.date >= lowerBound && $0.date < upperBound
        }
        let fixedExpenseSummary = summarizeFixedExpenses(
            fixedExpenses,
            from: lowerBound,
            through: endDay,
            calendar: calendar
        )
        let matchingGoals = savingsGoals.filter {
            !$0.isCompleted && $0.targetDate >= lowerBound && $0.targetDate < upperBound
        }
        let plannedSavings = matchingGoals.reduce(Decimal.zero) { total, goal in
            total + max(goal.targetAmount - goal.savedAmount, 0)
        }
        let variableExpenseCategories = SpendingCategory.allCases.compactMap { category in
            let amount = matchingTransactions
                .filter { $0.category == category }
                .reduce(Decimal.zero) { $0 + $1.amount }
            return amount > 0 ? ReportSpendingCategoryTotal(category: category, amount: amount) : nil
        }
        let fixedExpenseCategories: [ReportFixedExpenseCategoryTotal] = ExpenseCategory.allCases.compactMap { category in
            guard let amount = fixedExpenseSummary.categoryTotals[category], amount > 0 else {
                return nil
            }
            return ReportFixedExpenseCategoryTotal(category: category, amount: amount)
        }

        return ReportSummary(
            totalIncome: matchingIncomes.reduce(Decimal.zero) { $0 + $1.amount },
            totalVariableExpenses: matchingTransactions.reduce(Decimal.zero) { $0 + $1.amount },
            totalFixedExpenses: fixedExpenseSummary.total,
            plannedSavings: plannedSavings,
            entryCount: matchingTransactions.count
                + matchingIncomes.count
                + fixedExpenseSummary.occurrenceCount
                + matchingGoals.count,
            variableExpenseCategories: variableExpenseCategories,
            fixedExpenseCategories: fixedExpenseCategories
        )
    }

    private func summarizeFixedExpenses(
        _ expenses: [FixedExpense],
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) -> FixedExpenseReportSummary {
        expenses.reduce(into: FixedExpenseReportSummary()) { result, expense in
            guard expense.isActive,
                  var dueDate = firstDueDate(
                    forDay: expense.dueDay,
                    from: startDate,
                    calendar: calendar
                  ),
                  dueDate <= endDate else {
                return
            }

            while dueDate <= endDate {
                result.total += expense.amount
                result.occurrenceCount += 1
                result.categoryTotals[expense.category, default: .zero] += expense.amount

                guard let nextDate = nextDueDate(
                    after: dueDate,
                    recurrence: expense.recurrence,
                    customMonths: expense.customRecurrenceMonths,
                    calendar: calendar
                ), nextDate > dueDate else {
                    break
                }
                dueDate = nextDate
            }
        }
    }

    private func firstDueDate(
        forDay day: Int,
        from date: Date,
        calendar: Calendar
    ) -> Date? {
        let safeDay = min(max(day, 1), 28)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = safeDay

        guard let dueDateThisMonth = calendar.date(from: components) else {
            return nil
        }
        if dueDateThisMonth >= calendar.startOfDay(for: date) {
            return dueDateThisMonth
        }
        return calendar.date(byAdding: .month, value: 1, to: dueDateThisMonth)
    }

    private func nextDueDate(
        after date: Date,
        recurrence: ExpenseRecurrence,
        customMonths: Int,
        calendar: Calendar
    ) -> Date? {
        switch recurrence {
        case .weekly:
            calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual:
            calendar.date(byAdding: .month, value: 6, to: date)
        case .custom:
            calendar.date(byAdding: .month, value: max(customMonths, 1), to: date)
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
