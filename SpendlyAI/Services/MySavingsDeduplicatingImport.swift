import Foundation
import SwiftData
import CryptoKit

struct MySavingsImportOutcome {
    struct Conflict: Identifiable {
        let id: String
        let title: String
        let reason: String
        let localAmount: Decimal?
        let sourceAmount: Decimal
    }
    var created = 0
    var updated = 0
    var unchanged = 0
    var olderFilesSkipped = 0
    var linked = 0
    var conflicts: [Conflict] = []
}

@MainActor
enum MySavingsDeduplicatingImport {
    enum Record {
        case expense(Transaction), income(Income), fixed(FixedExpense)
        var sourceID: String? {
            get { switch self { case .expense(let x): x.mySavingsSourceID; case .income(let x): x.mySavingsSourceID; case .fixed(let x): x.mySavingsSourceID } }
            nonmutating set { switch self { case .expense(let x): x.mySavingsSourceID = newValue; case .income(let x): x.mySavingsSourceID = newValue; case .fixed(let x): x.mySavingsSourceID = newValue } }
        }
        var importedFingerprint: String? {
            get { switch self { case .expense(let x): x.mySavingsSourceFingerprint; case .income(let x): x.mySavingsSourceFingerprint; case .fixed(let x): x.mySavingsSourceFingerprint } }
            nonmutating set { switch self { case .expense(let x): x.mySavingsSourceFingerprint = newValue; case .income(let x): x.mySavingsSourceFingerprint = newValue; case .fixed(let x): x.mySavingsSourceFingerprint = newValue } }
        }
        var sourceExportedAt: Date? {
            get { switch self { case .expense(let x): x.mySavingsSourceExportedAt; case .income(let x): x.mySavingsSourceExportedAt; case .fixed(let x): x.mySavingsSourceExportedAt } }
            nonmutating set { switch self { case .expense(let x): x.mySavingsSourceExportedAt = newValue; case .income(let x): x.mySavingsSourceExportedAt = newValue; case .fixed(let x): x.mySavingsSourceExportedAt = newValue } }
        }
        var title: String { switch self { case .expense(let x): x.transactionDescription; case .income(let x): x.incomeDescription; case .fixed(let x): x.name } }
        var amount: Decimal { switch self { case .expense(let x): x.amount; case .income(let x): x.amount; case .fixed(let x): x.amount } }
        var dueDate: Date? { switch self { case .expense(let x): x.dueDate ?? x.date; case .income(let x): x.dueDate ?? x.date; case .fixed(let x): x.dueDate } }
        var isIncome: Bool { if case .income = self { true } else { false } }
        var fingerprint: String {
            func date(_ value: Date?) -> String { value.map { String($0.timeIntervalSinceReferenceDate) } ?? "nil" }
            var parts: [String]
            switch self {
            case .expense(let x):
                parts = ["expense", money(x.amount), date(x.date), x.category.rawValue, x.customCategoryName ?? "", x.transactionDescription, String(x.isEssential), x.notes ?? "", date(x.dueDate), date(x.settledDate), x.paymentStatus.rawValue]
            case .income(let x):
                parts = ["income", money(x.amount), date(x.date), x.category.rawValue, x.customCategoryName ?? "", x.incomeDescription, x.notes ?? "", x.recurrence.rawValue, String(x.isActive), date(x.dueDate), date(x.settledDate), x.paymentStatus.rawValue]
            case .fixed(let x):
                parts = ["fixed", x.name, money(x.amount), String(x.dueDay), x.category.rawValue, x.customCategoryName ?? "", x.recurrence.rawValue, String(x.customRecurrenceMonths), String(x.isActive), date(x.dueDate), date(x.settledDate), x.paymentStatus.rawValue]
            }
            // Length-prefix fields so labels containing separators cannot collide.
            let bytes = parts.map { String($0.utf8.count) + ":" + $0 }.joined()
            return SHA256.hash(data: Data(bytes.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        func potentiallyMatches(_ other: Record) -> Bool {
            let clean: (String) -> String = { $0.replacingOccurrences(of: "Copy of ", with: "", options: [.anchored,.caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines) }
            return isIncome == other.isIncome && clean(title) == clean(other.title)
                && dueDate == other.dueDate
        }
        func insert(into context: ModelContext) {
            switch self { case .expense(let x): context.insert(x); case .income(let x): context.insert(x); case .fixed(let x): context.insert(x) }
        }
        func update(from new: Record) -> Bool {
            switch (self,new) {
            case (.expense(let x),.expense(let y)):
                x.amount = y.amount; x.date = y.date; x.category = y.category; x.customCategoryName = y.customCategoryName
                x.transactionDescription = y.transactionDescription; x.isEssential = y.isEssential; x.notes = y.notes
                x.dueDate = y.dueDate; x.settledDate = y.settledDate; x.paymentStatus = y.paymentStatus
            case (.income(let x),.income(let y)):
                x.amount = y.amount; x.date = y.date; x.category = y.category; x.customCategoryName = y.customCategoryName
                x.incomeDescription = y.incomeDescription; x.notes = y.notes; x.recurrence = y.recurrence; x.isActive = y.isActive
                x.dueDate = y.dueDate; x.settledDate = y.settledDate; x.paymentStatus = y.paymentStatus
            case (.fixed(let x),.fixed(let y)):
                x.name = y.name; x.amount = y.amount; x.dueDay = y.dueDay; x.category = y.category; x.customCategoryName = y.customCategoryName
                x.recurrence = y.recurrence; x.customRecurrenceMonths = y.customRecurrenceMonths; x.isActive = y.isActive
                x.dueDate = y.dueDate; x.settledDate = y.settledDate; x.paymentStatus = y.paymentStatus
            default: return false
            }
            return true
        }
        private func money(_ value: Decimal) -> String {
            var input = value, rounded = Decimal.zero
            NSDecimalRound(&rounded, &input, 2, .plain)
            return NSDecimalNumber(decimal: rounded).stringValue
        }
    }

    static func apply(_ plan: MySavingsImportPlan, to modelContext: ModelContext, linkLegacyMatches: Bool, allowNewAlongsideUntracked: Bool) throws -> MySavingsImportOutcome {
        let context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        var existing = try context.fetch(FetchDescriptor<Transaction>()).map(Record.expense)
            + context.fetch(FetchDescriptor<Income>()).map(Record.income)
            + context.fetch(FetchDescriptor<FixedExpense>()).map(Record.fixed)
        var incoming: [(String,Record)] = []
        incoming += plan.expenses.map { ($0.sourceID,.expense(Transaction(amount:$0.amount,date:$0.date,category:$0.category,transactionDescription:$0.title,notes:$0.notes,dueDate:$0.dueDate,settledDate:$0.settledDate,paymentStatus:$0.paymentStatus))) }
        incoming += plan.incomes.map { ($0.sourceID,.income(Income(amount:$0.amount,date:$0.date,category:$0.category,incomeDescription:$0.title,notes:$0.notes,recurrence:$0.recurrence,isActive:$0.isActive,dueDate:$0.dueDate,settledDate:$0.settledDate,paymentStatus:$0.paymentStatus))) }
        incoming += plan.fixedExpenses.map { ($0.sourceID,.fixed(FixedExpense(name:$0.name,amount:$0.amount,dueDay:$0.dueDay,category:$0.category,recurrence:$0.recurrence,customRecurrenceMonths:$0.customRecurrenceMonths,isActive:true,dueDate:$0.dueDate,paymentStatus:.pending))) }
        guard incoming.allSatisfy({ !$0.0.isEmpty }), Set(incoming.map { $0.0 }).count == incoming.count else { throw MySavingsImportError.unreadableFile }
        var result = MySavingsImportOutcome()
        func conflict(_ id: String, _ row: Record, _ local: Record?, _ reason: String) {
            result.conflicts.append(.init(id:id,title:row.title,reason:reason,localAmount:local?.amount,sourceAmount:row.amount))
        }
        do {
            for (id,row) in incoming {
                let matches = existing.filter { $0.sourceID == id }
                if matches.count > 1 { conflict(id,row,matches.first,"Flere poster med samme kilde-ID. Ingen er endret."); continue }
                if let old = matches.first {
                    if let last = old.sourceExportedAt, plan.exportedAt < last { result.olderFilesSkipped += 1; continue }
                    if old.importedFingerprint == row.fingerprint { old.sourceExportedAt = plan.exportedAt; result.unchanged += 1; continue }
                    guard old.importedFingerprint == old.fingerprint else { conflict(id,row,old,"Posten er endret lokalt. Ingen verdier er overskrevet."); continue }
                    if old.update(from: row) {
                        old.importedFingerprint = old.fingerprint
                        old.sourceExportedAt = plan.exportedAt
                        result.updated += 1
                    } else if case .fixed(let fixed) = old, case .expense(let paid) = row, paid.paymentStatus == .settled {
                        // Retain the original planning record, but stop it generating further spending.
                        fixed.isActive = false; fixed.paymentStatus = .settled; fixed.settledDate = paid.settledDate
                        old.sourceID = "retired:" + id
                        row.sourceID = id; row.importedFingerprint = row.fingerprint; row.sourceExportedAt = plan.exportedAt; row.insert(into:context)
                        existing.append(row)
                        result.updated += 1
                    } else { conflict(id,row,old,"Posttypen er endret. Kontroller manuelt; eksisterende post er beholdt.") }
                    continue
                }
                let legacy = existing.filter { $0.sourceID == nil && $0.potentiallyMatches(row) }
                if !legacy.isEmpty {
                    let exact = legacy.filter { $0.fingerprint == row.fingerprint }
                    if linkLegacyMatches, legacy.count == 1, incoming.filter({ $0.1.fingerprint == row.fingerprint }).count == 1, let match = exact.first {
                        match.sourceID = id; match.importedFingerprint = match.fingerprint; match.sourceExportedAt = plan.exportedAt; result.linked += 1
                    } else { conflict(id,row,legacy.first,legacy.count == 1 && exact.count == 1 ? "Helt lik tidligere post. Slå på «Knytt til tidligere import» og importer originalfilen igjen." : "Tidligere post kan ikke kobles sikkert. Kontroller manuelt; ingen er overskrevet.") }
                    continue
                }
                if !allowNewAlongsideUntracked && existing.contains(where: { $0.sourceID == nil }) {
                    conflict(id,row,nil,"Kan være en eldre import uten kilde-ID. Importer originalfilen først. Tillat bare nye poster etter manuell kontroll."); continue
                }
                row.sourceID = id; row.importedFingerprint = row.fingerprint; row.sourceExportedAt = plan.exportedAt
                row.insert(into:context); existing.append(row); result.created += 1
            }
            try context.save()
            return result
        } catch { context.rollback(); throw error }
    }
}
