//
//  GoalPlanningService.swift
//  SpendlyAI
//

import Foundation

struct GoalPlan: Equatable {
    let progress: Double
    let remainingAmount: Decimal
    let weeklySavingsNeeded: Decimal
    let monthlySavingsNeeded: Decimal
    let daysRemaining: Int
    let isCompleted: Bool
}

struct GoalPlanningService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func plan(for goal: SavingsGoal, today: Date = .now) -> GoalPlan {
        plan(
            targetAmount: goal.targetAmount,
            savedAmount: goal.savedAmount,
            targetDate: goal.targetDate,
            isCompleted: goal.isCompleted,
            today: today
        )
    }

    func plan(
        targetAmount: Decimal,
        savedAmount: Decimal,
        targetDate: Date,
        isCompleted: Bool = false,
        today: Date = .now
    ) -> GoalPlan {
        let safeTargetAmount = max(targetAmount, 0)
        let safeSavedAmount = max(savedAmount, 0)
        let remainingAmount = max(safeTargetAmount - safeSavedAmount, 0)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedTargetDate = calendar.startOfDay(for: targetDate)
        let daysRemaining = max(calendar.dateComponents([.day], from: normalizedToday, to: normalizedTargetDate).day ?? 0, 0)
        let savingsDays = max(daysRemaining, 1)
        let weeksRemaining = max(Int(ceil(Double(savingsDays) / 7.0)), 1)
        let monthsRemaining = max(Int(ceil(Double(savingsDays) / 30.0)), 1)
        let progress = safeTargetAmount > 0
            ? min(max((safeSavedAmount as NSDecimalNumber).doubleValue / (safeTargetAmount as NSDecimalNumber).doubleValue, 0), 1)
            : 0

        return GoalPlan(
            progress: progress,
            remainingAmount: remainingAmount,
            weeklySavingsNeeded: remainingAmount / Decimal(weeksRemaining),
            monthlySavingsNeeded: remainingAmount / Decimal(monthsRemaining),
            daysRemaining: daysRemaining,
            isCompleted: isCompleted || remainingAmount <= 0
        )
    }
}
