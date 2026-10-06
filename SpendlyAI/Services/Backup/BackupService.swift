import Foundation
import SwiftData

struct SpendlyBackup: Codable, Equatable, Identifiable, Sendable {
    static let currentFormatVersion = 1

    var id: Date { createdAt }

    let formatVersion: Int
    let createdAt: Date
    let profile: ProfileRecord?
    let transactions: [TransactionRecord]
    let incomes: [IncomeRecord]
    let fixedExpenses: [FixedExpenseRecord]
    let savingsGoals: [SavingsGoalRecord]

    struct ProfileRecord: Codable, Equatable, Sendable {
        let monthlyNetIncome: String
        let paydayDay: Int
        let budgetPeriodStart: Date
        let budgetPeriodEnd: Date
        let currencyCode: String
        let minimumBuffer: String
        let createdAt: Date
        let updatedAt: Date
    }

    struct TransactionRecord: Codable, Equatable, Sendable {
        let amount: String
        let date: Date
        let category: SpendingCategory
        let transactionDescription: String
        let isEssential: Bool
        let notes: String?
        let dueDate: Date?
        let settledDate: Date?
        let paymentStatus: PaymentStatus?
    }

    struct IncomeRecord: Codable, Equatable, Sendable {
        let amount: String
        let date: Date
        let category: IncomeCategory
        let incomeDescription: String
        let notes: String?
        let recurrence: IncomeRecurrence
        let isActive: Bool
        let dueDate: Date?
        let settledDate: Date?
        let paymentStatus: PaymentStatus?

        init(
            amount: String,
            date: Date,
            category: IncomeCategory,
            incomeDescription: String,
            notes: String?,
            recurrence: IncomeRecurrence = .oneTime,
            isActive: Bool = true,
            dueDate: Date? = nil,
            settledDate: Date? = nil,
            paymentStatus: PaymentStatus? = nil
        ) {
            self.amount = amount
            self.date = date
            self.category = category
            self.incomeDescription = incomeDescription
            self.notes = notes
            self.recurrence = recurrence
            self.isActive = isActive
            self.dueDate = dueDate
            self.settledDate = settledDate
            self.paymentStatus = paymentStatus
        }

        private enum CodingKeys: String, CodingKey {
            case amount, date, category, incomeDescription, notes, recurrence, isActive
            case dueDate, settledDate, paymentStatus
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            amount = try container.decode(String.self, forKey: .amount)
            date = try container.decode(Date.self, forKey: .date)
            category = try container.decode(IncomeCategory.self, forKey: .category)
            incomeDescription = try container.decode(String.self, forKey: .incomeDescription)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            recurrence = try container.decodeIfPresent(IncomeRecurrence.self, forKey: .recurrence) ?? .oneTime
            isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
            dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
            settledDate = try container.decodeIfPresent(Date.self, forKey: .settledDate)
            paymentStatus = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus)
        }
    }

    struct FixedExpenseRecord: Codable, Equatable, Sendable {
        let name: String
        let amount: String
        let dueDay: Int
        let category: ExpenseCategory
        let recurrence: ExpenseRecurrence
        let customRecurrenceMonths: Int?
        let isActive: Bool
        let dueDate: Date?
        let settledDate: Date?
        let paymentStatus: PaymentStatus?
    }

    struct SavingsGoalRecord: Codable, Equatable, Sendable {
        let name: String
        let targetAmount: String
        let targetDate: Date
        let savedAmount: String
        let priority: GoalPriority
        let isCompleted: Bool
    }

    init(
        formatVersion: Int,
        createdAt: Date,
        profile: ProfileRecord?,
        transactions: [TransactionRecord],
        incomes: [IncomeRecord] = [],
        fixedExpenses: [FixedExpenseRecord],
        savingsGoals: [SavingsGoalRecord]
    ) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.profile = profile
        self.transactions = transactions
        self.incomes = incomes
        self.fixedExpenses = fixedExpenses
        self.savingsGoals = savingsGoals
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, createdAt, profile, transactions, incomes, fixedExpenses, savingsGoals
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        profile = try container.decodeIfPresent(ProfileRecord.self, forKey: .profile)
        transactions = try container.decode([TransactionRecord].self, forKey: .transactions)
        incomes = try container.decodeIfPresent([IncomeRecord].self, forKey: .incomes) ?? []
        fixedExpenses = try container.decode([FixedExpenseRecord].self, forKey: .fixedExpenses)
        savingsGoals = try container.decode([SavingsGoalRecord].self, forKey: .savingsGoals)
    }

    var summary: BackupSummary {
        BackupSummary(
            createdAt: createdAt,
            formatVersion: formatVersion,
            profileCount: profile == nil ? 0 : 1,
            transactionCount: transactions.count,
            incomeCount: incomes.count,
            fixedExpenseCount: fixedExpenses.count,
            savingsGoalCount: savingsGoals.count
        )
    }
}

struct BackupSummary: Equatable, Sendable {
    let createdAt: Date
    let formatVersion: Int
    let profileCount: Int
    let transactionCount: Int
    let incomeCount: Int
    let fixedExpenseCount: Int
    let savingsGoalCount: Int

    init(
        createdAt: Date,
        formatVersion: Int,
        profileCount: Int,
        transactionCount: Int,
        incomeCount: Int = 0,
        fixedExpenseCount: Int,
        savingsGoalCount: Int
    ) {
        self.createdAt = createdAt
        self.formatVersion = formatVersion
        self.profileCount = profileCount
        self.transactionCount = transactionCount
        self.incomeCount = incomeCount
        self.fixedExpenseCount = fixedExpenseCount
        self.savingsGoalCount = savingsGoalCount
    }
}

enum BackupError: Error, Equatable {
    case unreadableFile
    case unsupportedVersion(Int)
    case invalidData
}

struct BackupService {
    private static let decimalLocale = Locale(identifier: "en_US_POSIX")

    func makeBackup(
        profile: UserFinancialProfile?,
        transactions: [Transaction],
        incomes: [Income] = [],
        fixedExpenses: [FixedExpense],
        savingsGoals: [SavingsGoal],
        createdAt: Date = .now
    ) -> SpendlyBackup {
        SpendlyBackup(
            formatVersion: SpendlyBackup.currentFormatVersion,
            createdAt: createdAt,
            profile: profile.map {
                .init(
                    monthlyNetIncome: decimalString($0.monthlyNetIncome),
                    paydayDay: $0.paydayDay,
                    budgetPeriodStart: $0.budgetPeriodStart,
                    budgetPeriodEnd: $0.budgetPeriodEnd,
                    currencyCode: $0.currencyCode,
                    minimumBuffer: decimalString($0.minimumBuffer),
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            transactions: transactions.map {
                .init(
                    amount: decimalString($0.amount),
                    date: $0.date,
                    category: $0.category,
                    transactionDescription: $0.transactionDescription,
                    isEssential: $0.isEssential,
                    notes: $0.notes,
                    dueDate: $0.dueDate,
                    settledDate: $0.settledDate,
                    paymentStatus: $0.paymentStatus
                )
            },
            incomes: incomes.map {
                .init(
                    amount: decimalString($0.amount),
                    date: $0.date,
                    category: $0.category,
                    incomeDescription: $0.incomeDescription,
                    notes: $0.notes,
                    recurrence: $0.recurrence,
                    isActive: $0.isActive,
                    dueDate: $0.dueDate,
                    settledDate: $0.settledDate,
                    paymentStatus: $0.paymentStatus
                )
            },
            fixedExpenses: fixedExpenses.map {
                .init(
                    name: $0.name,
                    amount: decimalString($0.amount),
                    dueDay: $0.dueDay,
                    category: $0.category,
                    recurrence: $0.recurrence,
                    customRecurrenceMonths: $0.customRecurrenceMonths,
                    isActive: $0.isActive,
                    dueDate: $0.dueDate,
                    settledDate: $0.settledDate,
                    paymentStatus: $0.paymentStatus
                )
            },
            savingsGoals: savingsGoals.map {
                .init(
                    name: $0.name,
                    targetAmount: decimalString($0.targetAmount),
                    targetDate: $0.targetDate,
                    savedAmount: decimalString($0.savedAmount),
                    priority: $0.priority,
                    isCompleted: $0.isCompleted
                )
            }
        )
    }

    func encode(_ backup: SpendlyBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    func decodeAndValidate(_ data: Data) throws -> SpendlyBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: SpendlyBackup
        do {
            backup = try decoder.decode(SpendlyBackup.self, from: data)
        } catch {
            throw BackupError.unreadableFile
        }

        guard backup.formatVersion == SpendlyBackup.currentFormatVersion else {
            throw BackupError.unsupportedVersion(backup.formatVersion)
        }

        guard validate(backup) else {
            throw BackupError.invalidData
        }

        return backup
    }

    @MainActor
    func restore(_ backup: SpendlyBackup, in modelContext: ModelContext) throws {
        guard validate(backup) else {
            throw BackupError.invalidData
        }

        do {
            try modelContext.transaction {
                try modelContext.delete(model: UserFinancialProfile.self)
                try modelContext.delete(model: Transaction.self)
                try modelContext.delete(model: Income.self)
                try modelContext.delete(model: FixedExpense.self)
                try modelContext.delete(model: SavingsGoal.self)

                if let profile = backup.profile {
                    modelContext.insert(UserFinancialProfile(
                        monthlyNetIncome: decimal(profile.monthlyNetIncome)!,
                        paydayDay: profile.paydayDay,
                        budgetPeriodStart: profile.budgetPeriodStart,
                        budgetPeriodEnd: profile.budgetPeriodEnd,
                        currencyCode: profile.currencyCode,
                        minimumBuffer: decimal(profile.minimumBuffer)!,
                        createdAt: profile.createdAt,
                        updatedAt: profile.updatedAt
                    ))
                }

                for item in backup.transactions {
                    modelContext.insert(Transaction(
                        amount: decimal(item.amount)!,
                        date: item.date,
                        category: item.category,
                        transactionDescription: item.transactionDescription,
                        isEssential: item.isEssential,
                        notes: item.notes,
                        dueDate: item.dueDate,
                        settledDate: item.settledDate,
                        paymentStatus: item.paymentStatus ?? .settled
                    ))
                }

                for item in backup.incomes {
                    modelContext.insert(Income(
                        amount: decimal(item.amount)!,
                        date: item.date,
                        category: item.category,
                        incomeDescription: item.incomeDescription,
                        notes: item.notes,
                        recurrence: item.recurrence,
                        isActive: item.isActive,
                        dueDate: item.dueDate,
                        settledDate: item.settledDate,
                        paymentStatus: item.paymentStatus ?? .settled
                    ))
                }

                for item in backup.fixedExpenses {
                    modelContext.insert(FixedExpense(
                        name: item.name,
                        amount: decimal(item.amount)!,
                        dueDay: item.dueDay,
                        category: item.category,
                        recurrence: item.recurrence,
                        customRecurrenceMonths: item.customRecurrenceMonths ?? 1,
                        isActive: item.isActive,
                        dueDate: item.dueDate,
                        settledDate: item.settledDate,
                        paymentStatus: item.paymentStatus ?? .settled
                    ))
                }

                for item in backup.savingsGoals {
                    modelContext.insert(SavingsGoal(
                        name: item.name,
                        targetAmount: decimal(item.targetAmount)!,
                        targetDate: item.targetDate,
                        savedAmount: decimal(item.savedAmount)!,
                        priority: item.priority,
                        isCompleted: item.isCompleted
                    ))
                }
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func validate(_ backup: SpendlyBackup) -> Bool {
        // Existing app versions may contain empty labels or an expired budget
        // period. Those values are still representable by the models and must
        // round-trip safely. Validate only invariants required to reconstruct
        // the data without corruption.
        let profileIsValid = backup.profile.map {
            decimal($0.monthlyNetIncome) != nil
                && decimal($0.minimumBuffer) != nil
        } ?? true

        let transactionsAreValid = backup.transactions.allSatisfy {
            decimal($0.amount) != nil
        }

        let incomesAreValid = backup.incomes.allSatisfy {
            decimal($0.amount) != nil
        }

        let expensesAreValid = backup.fixedExpenses.allSatisfy {
            decimal($0.amount) != nil
        }

        let goalsAreValid = backup.savingsGoals.allSatisfy {
            decimal($0.targetAmount) != nil
                && decimal($0.savedAmount) != nil
        }

        return profileIsValid && transactionsAreValid && incomesAreValid && expensesAreValid && goalsAreValid
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func decimal(_ value: String) -> Decimal? {
        let number = NSDecimalNumber(string: value, locale: Self.decimalLocale)
        guard number != .notANumber else { return nil }
        return number.decimalValue
    }
}
