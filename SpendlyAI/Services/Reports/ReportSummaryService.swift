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
            $0.category.countsAsSpending && $0.date >= lowerBound && $0.date < upperBound
        }
        let matchingIncomes = incomes.filter {
            $0.category.countsAsIncome && $0.date >= lowerBound && $0.date < upperBound
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
            for payment in expense.paymentHistory where payment.dueDate >= startDate
                && payment.dueDate <= endDate && payment.category.countsAsSpending {
                result.total += payment.amount
                result.occurrenceCount += 1
                result.categoryTotals[payment.category, default: .zero] += payment.amount
            }
            guard expense.category.countsAsSpending else { return }
            for _ in FixedExpensePaymentService.unpaidDates(for: expense, from: startDate,
                                                           through: endDate, calendar: calendar) {
                result.total += expense.amount
                result.occurrenceCount += 1
                result.categoryTotals[expense.category, default: .zero] += expense.amount
            }
        }
    }
}
