//
//  BudgetService.swift
//  SpendlyAI
//

import Foundation

public struct BudgetInput {
    public let availableMoney: Decimal
    public let periodStart: Date
    public let nextIncomeDate: Date
    public let fixedExpenses: [BudgetFixedExpense]
    public let savingsGoals: [BudgetSavingsGoal]
    public let transactions: [BudgetTransaction]
    public let minimumBuffer: Decimal

    public init(
        availableMoney: Decimal,
        periodStart: Date,
        nextIncomeDate: Date,
        fixedExpenses: [BudgetFixedExpense] = [],
        savingsGoals: [BudgetSavingsGoal] = [],
        transactions: [BudgetTransaction] = [],
        minimumBuffer: Decimal = 0
    ) {
        self.availableMoney = availableMoney
        self.periodStart = periodStart
        self.nextIncomeDate = nextIncomeDate
        self.fixedExpenses = fixedExpenses
        self.savingsGoals = savingsGoals
        self.transactions = transactions
        self.minimumBuffer = minimumBuffer
    }
}

public struct BudgetFixedExpense {
    public let amount: Decimal
    public let dueDay: Int
    let dueDate: Date?
    let recurrence: ExpenseRecurrence
    let customRecurrenceMonths: Int
    public let isActive: Bool

    public init(amount: Decimal, dueDay: Int, isActive: Bool = true) {
        self.init(
            amount: amount,
            dueDay: dueDay,
            dueDate: nil,
            recurrence: .monthly,
            customRecurrenceMonths: 1,
            isActive: isActive
        )
    }

    init(
        amount: Decimal,
        dueDay: Int,
        dueDate: Date? = nil,
        recurrence: ExpenseRecurrence,
        customRecurrenceMonths: Int = 1,
        isActive: Bool = true
    ) {
        self.amount = amount
        self.dueDay = dueDay
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.customRecurrenceMonths = max(customRecurrenceMonths, 1)
        self.isActive = isActive
    }
}

public struct BudgetSavingsGoal {
    public let targetAmount: Decimal
    public let savedAmount: Decimal
    public let targetDate: Date

    public init(targetAmount: Decimal, savedAmount: Decimal, targetDate: Date) {
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.targetDate = targetDate
    }
}

public struct BudgetTransaction {
    public let amount: Decimal
    public let date: Date
    public let isSettled: Bool

    public init(amount: Decimal, date: Date, isSettled: Bool = true) {
        self.amount = amount
        self.date = date
        self.isSettled = isSettled
    }
}

public struct BudgetResult {
    public let availableUntilNextIncome: Decimal
    public let upcomingFixedExpenses: Decimal
    public let plannedSavings: Decimal
    public let minimumBuffer: Decimal
    public let disposableAmount: Decimal
    public let daysRemaining: Int
    public let recommendedDailyMaximum: Decimal
    public let spentToday: Decimal
    public let remainingSafeAmountToday: Decimal
    public let isNegativeBudget: Bool
}

public struct BudgetService {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func calculateBudget(for input: BudgetInput, today: Date = .now) -> BudgetResult {
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedNextIncomeDate = calendar.startOfDay(for: input.nextIncomeDate)
        let daysRemaining = max(calendar.dateComponents([.day], from: normalizedToday, to: normalizedNextIncomeDate).day ?? 0, 1)
        let upcomingFixedExpenses = sumUpcomingFixedExpenses(
            input.fixedExpenses,
            from: normalizedToday,
            through: normalizedNextIncomeDate
        )
        let plannedSavings = sumPlannedSavings(input.savingsGoals, through: normalizedNextIncomeDate)
        let spentToday = sumSpentToday(input.transactions, today: normalizedToday)
        let spentBeforeToday = sumSpentBeforeToday(
            input.transactions,
            from: calendar.startOfDay(for: input.periodStart),
            through: normalizedToday
        )
        let disposableAmount = input.availableMoney
            - spentBeforeToday
            - upcomingFixedExpenses
            - plannedSavings
            - input.minimumBuffer
        let recommendedDailyMaximum = disposableAmount / Decimal(daysRemaining)
        let remainingSafeAmountToday = recommendedDailyMaximum - spentToday

        return BudgetResult(
            availableUntilNextIncome: input.availableMoney,
            upcomingFixedExpenses: upcomingFixedExpenses,
            plannedSavings: plannedSavings,
            minimumBuffer: input.minimumBuffer,
            disposableAmount: disposableAmount,
            daysRemaining: daysRemaining,
            recommendedDailyMaximum: recommendedDailyMaximum,
            spentToday: spentToday,
            remainingSafeAmountToday: remainingSafeAmountToday,
            isNegativeBudget: disposableAmount < 0
        )
    }

    private func sumUpcomingFixedExpenses(
        _ expenses: [BudgetFixedExpense],
        from startDate: Date,
        through endDate: Date
    ) -> Decimal {
        expenses.reduce(0) { total, expense in
            guard expense.isActive,
                  var dueDate = firstOccurrence(for: expense, onOrAfter: startDate),
                  dueDate <= endDate else {
                return total
            }

            var expenseTotal: Decimal = 0
            while dueDate <= endDate {
                expenseTotal += expense.amount

                guard let nextDate = nextDueDate(after: dueDate, recurrence: expense.recurrence, customMonths: expense.customRecurrenceMonths),
                      nextDate > dueDate else {
                    break
                }
                dueDate = nextDate
            }

            return total + expenseTotal
        }
    }

    private func sumPlannedSavings(_ goals: [BudgetSavingsGoal], through nextIncomeDate: Date) -> Decimal {
        goals.reduce(0) { total, goal in
            guard goal.targetDate <= nextIncomeDate else { return total }
            return total + max(goal.targetAmount - goal.savedAmount, 0)
        }
    }

    private func sumSpentBeforeToday(
        _ transactions: [BudgetTransaction],
        from startDate: Date,
        through today: Date
    ) -> Decimal {
        transactions.reduce(0) { total, transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            guard transaction.isSettled,
                  transactionDate >= startDate,
                  transactionDate < today else { return total }
            return total + transaction.amount
        }
    }

    private func sumSpentToday(_ transactions: [BudgetTransaction], today: Date) -> Decimal {
        transactions.reduce(0) { total, transaction in
            guard transaction.isSettled,
                  calendar.isDate(transaction.date, inSameDayAs: today) else { return total }
            return total + transaction.amount
        }
    }

    private func firstOccurrence(for expense: BudgetFixedExpense, onOrAfter date: Date) -> Date? {
        let startDate = calendar.startOfDay(for: date)
        guard var occurrence = expense.dueDate.map({ calendar.startOfDay(for: $0) }) else {
            return nextDueDate(forDay: expense.dueDay, from: startDate)
        }

        while occurrence < startDate {
            guard let nextDate = nextDueDate(
                after: occurrence,
                recurrence: expense.recurrence,
                customMonths: expense.customRecurrenceMonths
            ), nextDate > occurrence else {
                return nil
            }
            occurrence = nextDate
        }
        return occurrence
    }

    private func nextDueDate(forDay day: Int, from date: Date) -> Date? {
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

    private func nextDueDate(after date: Date, recurrence: ExpenseRecurrence, customMonths: Int) -> Date? {
        switch recurrence {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual:
            return calendar.date(byAdding: .month, value: 6, to: date)
        case .custom:
            return calendar.date(byAdding: .month, value: max(customMonths, 1), to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

extension BudgetService {
    func makeInput(
        profile: UserFinancialProfile,
        fixedExpenses: [FixedExpense],
        savingsGoals: [SavingsGoal],
        transactions: [Transaction],
        incomes: [Income] = [],
        today: Date = .now
    ) -> BudgetInput {
        let additionalIncome = sumRealizedAdditionalIncome(
            incomes,
            from: profile.budgetPeriodStart,
            through: min(today, profile.budgetPeriodEnd)
        )

        return BudgetInput(
            availableMoney: profile.monthlyNetIncome + additionalIncome,
            periodStart: profile.budgetPeriodStart,
            nextIncomeDate: profile.budgetPeriodEnd,
            fixedExpenses: fixedExpenses.map { expense in
                BudgetFixedExpense(
                    amount: expense.amount,
                    dueDay: expense.dueDay,
                    dueDate: expense.dueDate,
                    recurrence: expense.recurrence,
                    customRecurrenceMonths: expense.customRecurrenceMonths,
                    isActive: expense.isActive
                )
            },
            savingsGoals: savingsGoals.filter { !$0.isCompleted }.map { goal in
                BudgetSavingsGoal(
                    targetAmount: goal.targetAmount,
                    savedAmount: goal.savedAmount,
                    targetDate: goal.targetDate
                )
            },
            transactions: transactions.map { transaction in
                BudgetTransaction(
                    amount: transaction.amount,
                    date: transaction.settledDate ?? transaction.date,
                    isSettled: transaction.paymentStatus == .settled
                        || transaction.paymentStatus == .withdrawn
                )
            },
            minimumBuffer: profile.minimumBuffer
        )
    }

    private func sumRealizedAdditionalIncome(
        _ incomes: [Income],
        from periodStart: Date,
        through endDate: Date
    ) -> Decimal {
        let normalizedPeriodStart = calendar.startOfDay(for: periodStart)
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        guard normalizedEndDate >= normalizedPeriodStart else { return 0 }

        return incomes.reduce(0) { total, income in
            guard income.isActive,
                  income.category != .salary,
                  income.paymentStatus == .settled || income.paymentStatus == .withdrawn else {
                return total
            }
            let normalizedIncomeDate = calendar.startOfDay(for: income.settledDate ?? income.date)

            if income.recurrence == .oneTime {
                guard normalizedIncomeDate >= normalizedPeriodStart,
                      normalizedIncomeDate <= normalizedEndDate else {
                    return total
                }
                return total + income.amount
            }

            var occurrence = normalizedIncomeDate
            while occurrence < normalizedPeriodStart {
                guard let next = nextIncomeDate(after: occurrence, recurrence: income.recurrence),
                      next > occurrence else {
                    return total
                }
                occurrence = next
            }

            var incomeTotal: Decimal = 0
            while occurrence <= normalizedEndDate {
                incomeTotal += income.amount
                guard let next = nextIncomeDate(after: occurrence, recurrence: income.recurrence),
                      next > occurrence else {
                    break
                }
                occurrence = next
            }
            return total + incomeTotal
        }
    }

    private func nextIncomeDate(after date: Date, recurrence: IncomeRecurrence) -> Date? {
        switch recurrence {
        case .oneTime:
            return nil
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
