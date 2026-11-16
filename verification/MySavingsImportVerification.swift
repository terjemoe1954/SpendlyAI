import Foundation
import SwiftData
@main struct Audit {
 @MainActor static func main() throws {
  let service = MySavingsImportService()
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let base = try service.decode(data)
  let schema = Schema([Transaction.self,Income.self,FixedExpense.self,UserFinancialProfile.self,DailyBudgetSnapshot.self,SavingsGoal.self,CustomCategory.self])
  let container = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,isStoredInMemoryOnly:true,cloudKitDatabase:.none)])
  let context = ModelContext(container)
  let first = try service.importPlan(base,into:context)
  precondition(first.created == base.totalCount && first.conflicts.isEmpty)
  let repeated = try service.importPlan(base,into:context)
  precondition(repeated.created == 0 && repeated.unchanged == base.totalCount)
  var object = try JSONSerialization.jsonObject(with:data) as! [String:Any]
  var rows = object["transactions"] as! [[String:Any]]
  let index = rows.firstIndex { ($0["type"] as? String) == "income" }!
  let sourceID = "mysavings:" + (rows[index]["id"] as! String).uppercased()
  rows[index]["amount"] = "12345.67"; object["transactions"] = rows
  object["exportedAt"] = "2026-12-01T12:00:00Z"
  let changed = try service.decode(JSONSerialization.data(withJSONObject:object))
  let update = try service.importPlan(changed,into:context)
  precondition(update.updated == 1 && update.created == 0 && update.conflicts.isEmpty)
  let fresh = ModelContext(container)
  let income = try fresh.fetch(FetchDescriptor<Income>()).first { $0.mySavingsSourceID == sourceID }!
  precondition(income.amount == Decimal(string:"12345.67")!)
  income.amount = 777; try fresh.save()
  rows[index]["amount"] = "54321"; object["transactions"] = rows; object["exportedAt"] = "2026-12-02T12:00:00Z"
  let localConflict = try service.importPlan(service.decode(JSONSerialization.data(withJSONObject:object)),into:context)
  precondition(localConflict.conflicts.count == 1 && localConflict.created == 0)
  let preserved = try ModelContext(container).fetch(FetchDescriptor<Income>()).first { $0.mySavingsSourceID == sourceID }!
  precondition(preserved.amount == 777)
  let older = try service.importPlan(base,into:context)
  precondition(older.created == 0 && older.olderFilesSkipped == base.totalCount)
  let backupService = BackupService()
  let snapshot = ModelContext(container)
  let backup = backupService.makeBackup(profile:nil,transactions:try snapshot.fetch(FetchDescriptor<Transaction>()),incomes:try snapshot.fetch(FetchDescriptor<Income>()),fixedExpenses:try snapshot.fetch(FetchDescriptor<FixedExpense>()),savingsGoals:[])
  let decoded = try backupService.decodeAndValidate(backupService.encode(backup))
  let restored = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,isStoredInMemoryOnly:true,cloudKitDatabase:.none)])
  try backupService.restore(decoded,in:ModelContext(restored))
  let restoredResult = try service.importPlan(changed,into:ModelContext(restored))
  precondition(restoredResult.created == 0 && restoredResult.unchanged + restoredResult.olderFilesSkipped == base.totalCount)
  let restoredIncome = try ModelContext(restored).fetch(FetchDescriptor<Income>()).first { $0.mySavingsSourceID == sourceID }!
  precondition(restoredIncome.amount == 777)
  // A recurring planned expense must stop contributing when the source marks it paid.
  if let fixedRow = base.fixedExpenses.first {
   var paidObject = try JSONSerialization.jsonObject(with:data) as! [String:Any]
   var paidRows = paidObject["transactions"] as! [[String:Any]]
   let paidIndex = paidRows.firstIndex { "mysavings:" + ($0["id"] as! String).uppercased() == fixedRow.sourceID }!
   paidRows[paidIndex]["status"] = "paid";paidRows[paidIndex]["isCompleted"] = true;paidRows[paidIndex]["paidDate"] = "2026-12-03T12:00:00Z"
   paidObject["transactions"] = paidRows;paidObject["exportedAt"] = "2026-12-03T12:00:00Z"
   let paidPlan = try service.decode(JSONSerialization.data(withJSONObject:paidObject))
   let paidResult = try service.importPlan(paidPlan,into:context)
   precondition(paidResult.updated >= 1 && paidResult.created == 0)
   let paidCheck = ModelContext(container)
   let planned = try paidCheck.fetch(FetchDescriptor<FixedExpense>()).first { $0.mySavingsSourceID == "retired:" + fixedRow.sourceID }!
   let actual = try paidCheck.fetch(FetchDescriptor<Transaction>()).filter { $0.mySavingsSourceID == fixedRow.sourceID }
   precondition(!planned.isActive && actual.count == 1 && actual[0].paymentStatus == .settled)
   let repeatPaid = try service.importPlan(paidPlan,into:context)
   precondition(repeatPaid.created == 0 && repeatPaid.updated == 0)
  }
  let legacyContainer = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,isStoredInMemoryOnly:true,cloudKitDatabase:.none)])
  _ = try service.importPlan(base,into:ModelContext(legacyContainer))
  let legacyContext = ModelContext(legacyContainer)
  for row in try legacyContext.fetch(FetchDescriptor<Transaction>()) { row.mySavingsSourceID = nil;row.mySavingsSourceFingerprint = nil;row.mySavingsSourceExportedAt = nil }
  for row in try legacyContext.fetch(FetchDescriptor<Income>()) { row.mySavingsSourceID = nil;row.mySavingsSourceFingerprint = nil;row.mySavingsSourceExportedAt = nil }
  for row in try legacyContext.fetch(FetchDescriptor<FixedExpense>()) { row.mySavingsSourceID = nil;row.mySavingsSourceFingerprint = nil;row.mySavingsSourceExportedAt = nil }
  try legacyContext.save()
  let legacyReview = try service.importPlan(base,into:ModelContext(legacyContainer))
  precondition(legacyReview.created == 0 && legacyReview.conflicts.count == base.totalCount)
  let linked = try service.importPlan(base,into:ModelContext(legacyContainer),linkLegacyMatches:true)
  precondition(linked.created == 0 && linked.linked > 0 && linked.linked + linked.conflicts.count == base.totalCount)
  print("SpendlyAI passed: ",base.totalCount,"rows; repeat, source update, local conflict, older-file protection")
 }
}
