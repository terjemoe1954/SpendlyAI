import Foundation
import UIKit

enum ReportEntryKind {
    case income
    case expense
}

struct ReportPDFEntry {
    let kind: ReportEntryKind
    let date: Date
    let title: String
    let amount: Decimal
    let status: String
    let statusValue: PaymentStatus
    let category: String
}

struct ReportPDFRequest {
    let appName: String
    let startDate: Date
    let endDate: Date
    let currencyCode: String
    let generatedAt: Date
    let summary: ReportSummary
    let entries: [ReportPDFEntry]
    let sortDescription: String
    let statusDescription: String
}

@MainActor
struct ReportPDFGenerator {
    private let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)

    func makePDF(
        for request: ReportPDFRequest,
        locale: Locale = .current
    ) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: request.appName + " – " + localized("report.invoiceTitle", locale: locale),
            kCGPDFContextAuthor as String: request.appName
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        return renderer.pdfData { context in
            let canvas = ReportPDFCanvas(
                context: context,
                pageBounds: pageBounds,
                locale: locale,
                currencyCode: request.currencyCode
            )
            canvas.beginPage()
            canvas.drawReport(request)
        }
    }

    private func localized(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }
}

@MainActor
private final class ReportPDFCanvas {
    private let context: UIGraphicsPDFRendererContext
    private let pageBounds: CGRect
    private let locale: Locale
    private let currencyCode: String
    private let margin: CGFloat = 48
    private let footerHeight: CGFloat = 36
    private var cursorY: CGFloat = 48
    private var pageNumber = 0

    private var contentWidth: CGFloat {
        pageBounds.width - (margin * 2)
    }

    private var contentBottom: CGFloat {
        pageBounds.height - margin - footerHeight
    }

    init(
        context: UIGraphicsPDFRendererContext,
        pageBounds: CGRect,
        locale: Locale,
        currencyCode: String
    ) {
        self.context = context
        self.pageBounds = pageBounds
        self.locale = locale
        self.currencyCode = currencyCode
    }

    func beginPage() {
        context.beginPage()
        pageNumber += 1
        cursorY = margin
        UIColor.white.setFill()
        UIRectFill(pageBounds)
    }

    func drawReport(_ request: ReportPDFRequest) {
        drawText(
            request.appName,
            font: .boldSystemFont(ofSize: 24),
            color: .black,
            spacingAfter: 4
        )
        drawText(
            localized("report.invoiceTitle"),
            font: .boldSystemFont(ofSize: 34),
            color: .black,
            spacingAfter: 18
        )

        let period = dateString(request.startDate) + " – " + dateString(request.endDate)
        drawMetadata(label: localized("Period"), value: period)
        drawMetadata(label: localized("Generated"), value: generatedDateString(request.generatedAt))
        drawMetadata(label: localized("report.sort"), value: request.sortDescription)
        drawMetadata(label: localized("report.statusFilter"), value: request.statusDescription)
        drawMetadata(label: localized("Entries"), value: String(request.entries.count))

        cursorY += 14
        drawEntryTable(request.entries)

        cursorY += 18
        drawSectionTitle(localized("Summary"))
        let receivedIncome = request.entries
            .filter { $0.kind == .income && $0.statusValue == .settled }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let pendingIncome = request.entries
            .filter { $0.kind == .income && $0.statusValue != .settled }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let paidExpenses = request.entries
            .filter { $0.kind == .expense && ($0.statusValue == .settled || $0.statusValue == .withdrawn) }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let unpaidExpenses = request.entries
            .filter { $0.kind == .expense && $0.statusValue != .settled && $0.statusValue != .withdrawn }
            .reduce(Decimal.zero) { $0 + $1.amount }

        drawAmountRow(localized("report.incomeReceived"), amount: receivedIncome, color: .systemGreen)
        drawAmountRow(localized("report.expensePaid"), amount: paidExpenses)
        drawAmountRow(localized("report.incomePending"), amount: pendingIncome, color: .systemOrange)
        drawAmountRow(localized("report.expenseUnpaid"), amount: unpaidExpenses, color: .systemOrange)

        drawFooter()
    }

    private func drawEntryTable(_ entries: [ReportPDFEntry]) {
        drawEntryTableHeader()

        for entry in entries {
            ensureSpace(for: 25)
            drawEntryRow(entry)
        }
    }

    private func drawEntryTableHeader() {
        ensureSpace(for: 28)
        let columns = entryColumnRects(height: 20)
        let titles = [
            localized("Date"),
            localized("Title"),
            localized("Amount"),
            localized("Status"),
            localized("Category")
        ]

        UIColor(white: 0.93, alpha: 1).setFill()
        UIRectFill(CGRect(x: margin, y: cursorY, width: contentWidth, height: 20))

        for (title, rect) in zip(titles, columns) {
            drawText(
                title,
                in: rect,
                font: .boldSystemFont(ofSize: 8),
                color: .darkGray,
                alignment: title == localized("Amount") ? .right : .left
            )
        }
        cursorY += 22
        drawDivider()
    }

    private func drawEntryRow(_ entry: ReportPDFEntry) {
        let columns = entryColumnRects(height: 18)
        let values = [
            dateString(entry.date),
            entry.title,
            MoneyFormatter.string(from: entry.amount, currencyCode: currencyCode, locale: locale),
            entry.status,
            entry.category
        ]

        for (index, value) in values.enumerated() {
            drawText(
                value,
                in: columns[index],
                font: .systemFont(ofSize: 8),
                color: .black,
                alignment: index == 2 ? .right : .left
            )
        }
        cursorY += 20
        drawDivider()
    }

    private func entryColumnRects(height: CGFloat) -> [CGRect] {
        let widths: [CGFloat] = [60, 170, 88, 78, 99]
        var x = margin
        return widths.map { width in
            defer { x += width }
            return CGRect(x: x, y: cursorY, width: width - 5, height: height)
        }
    }

    private func drawMetadata(label: String, value: String) {
        ensureSpace(for: 24)
        let line = label + ": " + value
        drawText(
            line,
            font: .systemFont(ofSize: 11),
            color: .darkGray,
            spacingAfter: 4
        )
    }

    private func drawSectionTitle(_ title: String) {
        ensureSpace(for: 42)
        drawText(
            title,
            font: .boldSystemFont(ofSize: 17),
            color: .black,
            spacingAfter: 8
        )
        drawDivider()
    }

    private func drawAmountRow(
        _ title: String,
        amount: Decimal,
        color: UIColor = .black
    ) {
        drawValueRow(
            title,
            value: MoneyFormatter.string(
                from: amount,
                currencyCode: currencyCode,
                locale: locale
            ),
            valueColor: color
        )
    }

    private func drawValueRow(
        _ title: String,
        value: String,
        valueColor: UIColor = .black
    ) {
        ensureSpace(for: 34)

        let rowRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 22)
        let titleRect = CGRect(x: rowRect.minX, y: rowRect.minY, width: rowRect.width * 0.52, height: rowRect.height)
        let valueRect = CGRect(x: titleRect.maxX, y: rowRect.minY, width: rowRect.width * 0.48, height: rowRect.height)

        drawText(
            title,
            in: titleRect,
            font: .systemFont(ofSize: 12),
            color: .black,
            alignment: .left
        )
        drawText(
            value,
            in: valueRect,
            font: .systemFont(ofSize: 12),
            color: valueColor,
            alignment: .right
        )
        cursorY += 28
        drawDivider()
    }

    private func drawDivider() {
        let dividerY = cursorY
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: margin, y: dividerY))
        divider.addLine(to: CGPoint(x: pageBounds.width - margin, y: dividerY))
        UIColor(white: 0.84, alpha: 1).setStroke()
        divider.lineWidth = 0.5
        divider.stroke()
        cursorY += 6
    }

    private func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) {
        let attributes = textAttributes(font: font, color: color, alignment: .left)
        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let height = ceil(boundingRect.height)
        ensureSpace(for: height + spacingAfter)
        drawText(
            text,
            in: CGRect(x: margin, y: cursorY, width: contentWidth, height: height),
            font: font,
            color: color,
            alignment: .left
        )
        cursorY += height + spacingAfter
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        NSString(string: text).draw(
            in: rect,
            withAttributes: textAttributes(font: font, color: color, alignment: alignment)
        )
    }

    private func textAttributes(
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func ensureSpace(for height: CGFloat) {
        guard cursorY + height > contentBottom else { return }
        drawFooter()
        beginPage()
    }

    private func drawFooter() {
        let footerRect = CGRect(
            x: margin,
            y: pageBounds.height - margin,
            width: contentWidth,
            height: 18
        )
        drawText(
            String(pageNumber),
            in: footerRect,
            font: .systemFont(ofSize: 9),
            color: .gray,
            alignment: .right
        )
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: locale)
    }

    private func dateString(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted, locale: locale)
        )
    }

    private func generatedDateString(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .numeric, time: .shortened, locale: locale)
        )
    }

    private func spendingCategoryTitle(_ category: SpendingCategory) -> String {
        switch category {
        case .subscriptions: localized("expenseCategory.subscriptions")
        case .insurance: localized("expenseCategory.insurance")
        case .gifts: localized("category.gifts")
        case .home: localized("category.home")
        case .income: localized("category.income")
        case .clothing: localized("category.clothing")
        case .communication: localized("category.communication")
        case .withdrawals: localized("category.withdrawals")
        case .developer: localized("category.developer")
        case .food: localized("category.food")
        case .groceries: localized("category.groceries")
        case .transport: localized("category.transport")
        case .shopping: localized("category.shopping")
        case .entertainment: localized("category.entertainment")
        case .gambling: localized("category.gambling")
        case .health: localized("category.health")
        case .bills: localized("category.bills")
        case .savings: localized("category.savings")
        case .other: localized("category.other")
        }
    }

    private func fixedExpenseCategoryTitle(_ category: ExpenseCategory) -> String {
        switch category {
        case .gifts: localized("category.gifts")
        case .income: localized("category.income")
        case .clothing: localized("category.clothing")
        case .communication: localized("category.communication")
        case .savings: localized("category.savings")
        case .withdrawals: localized("category.withdrawals")
        case .entertainment: localized("category.entertainment")
        case .developer: localized("category.developer")
        case .housing: localized("expenseCategory.housing")
        case .utilities: localized("expenseCategory.utilities")
        case .insurance: localized("expenseCategory.insurance")
        case .transport: localized("expenseCategory.transport")
        case .subscriptions: localized("expenseCategory.subscriptions")
        case .debt: localized("expenseCategory.debt")
        case .childcare: localized("expenseCategory.childcare")
        case .groceries: localized("expenseCategory.groceries")
        case .health: localized("expenseCategory.health")
        case .gambling: localized("expenseCategory.gambling")
        case .other: localized("expenseCategory.other")
        }
    }
}
