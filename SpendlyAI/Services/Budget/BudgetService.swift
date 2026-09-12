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
    public let isActive: Bool

    public init(amount: Decimal, dueDay: Int, isActive: Bool = true) {
        self.amount = amount
        self.dueDay = dueDay
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

    public init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
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
        let disposableAmount = input.availableMoney - upcomingFixedExpenses - plannedSavings - input.minimumBuffer
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
                  let dueDate = nextDueDate(forDay: expense.dueDay, from: startDate),
                  dueDate <= endDate else {
                return total
            }

            return total + expense.amount
        }
    }

    private func sumPlannedSavings(_ goals: [BudgetSavingsGoal], through nextIncomeDate: Date) -> Decimal {
        goals.reduce(0) { total, goal in
            guard goal.targetDate <= nextIncomeDate else { return total }
            return total + max(goal.targetAmount - goal.savedAmount, 0)
        }
    }

    private func sumSpentToday(_ transactions: [BudgetTransaction], today: Date) -> Decimal {
        transactions.reduce(0) { total, transaction in
            guard calendar.isDate(transaction.date, inSameDayAs: today) else { return total }
            return total + transaction.amount
        }
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
}

extension BudgetService {
    func makeInput(
        profile: UserFinancialProfile,
        fixedExpenses: [FixedExpense],
        savingsGoals: [SavingsGoal],
        transactions: [Transaction]
    ) -> BudgetInput {
        BudgetInput(
            availableMoney: profile.monthlyNetIncome,
            periodStart: profile.budgetPeriodStart,
            nextIncomeDate: profile.budgetPeriodEnd,
            fixedExpenses: fixedExpenses.map { expense in
                BudgetFixedExpense(
                    amount: expense.amount,
                    dueDay: expense.dueDay,
                    isActive: expense.isActive
                )
            },
            savingsGoals: savingsGoals.map { goal in
                BudgetSavingsGoal(
                    targetAmount: goal.targetAmount,
                    savedAmount: goal.savedAmount,
                    targetDate: goal.targetDate
                )
            },
            transactions: transactions.map { transaction in
                BudgetTransaction(amount: transaction.amount, date: transaction.date)
            },
            minimumBuffer: profile.minimumBuffer
        )
    }
}
