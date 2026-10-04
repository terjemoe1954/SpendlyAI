import Foundation
import UIKit

struct ReportPDFRequest {
    let appName: String
    let startDate: Date
    let endDate: Date
    let currencyCode: String
    let generatedAt: Date
    let summary: ReportSummary
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
            kCGPDFContextTitle as String: request.appName + " – " + localized("Reports", locale: locale),
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
            localized("Reports"),
            font: .boldSystemFont(ofSize: 34),
            color: .black,
            spacingAfter: 18
        )

        let period = dateString(request.startDate) + " – " + dateString(request.endDate)
        drawMetadata(label: localized("Period"), value: period)
        drawMetadata(label: localized("Currency"), value: request.currencyCode)
        drawMetadata(
            label: localized("Generated"),
            value: generatedDateString(request.generatedAt)
        )

        cursorY += 18
        drawSectionTitle(localized("Summary"))
        drawAmountRow(localized("Income"), amount: request.summary.totalIncome, color: .systemGreen)
        drawAmountRow(localized("Variable expenses"), amount: request.summary.totalVariableExpenses)
        drawAmountRow(localized("Fixed expenses"), amount: request.summary.totalFixedExpenses, color: .systemOrange)
        drawAmountRow(localized("Planned savings"), amount: request.summary.plannedSavings)
        drawAmountRow(
            localized("Net result"),
            amount: request.summary.netResult,
            color: request.summary.netResult < 0 ? .systemRed : .systemGreen
        )
        drawValueRow(localized("Entries"), value: String(request.summary.entryCount))

        if !request.summary.variableExpenseCategories.isEmpty {
            cursorY += 18
            drawSectionTitle(localized("Variable expenses by category"))
            for total in request.summary.variableExpenseCategories {
                drawAmountRow(
                    spendingCategoryTitle(total.category),
                    amount: total.amount
                )
            }
        }

        if !request.summary.fixedExpenseCategories.isEmpty {
            cursorY += 18
            drawSectionTitle(localized("Fixed expenses by category"))
            for total in request.summary.fixedExpenseCategories {
                drawAmountRow(
                    fixedExpenseCategoryTitle(total.category),
                    amount: total.amount,
                    color: .systemOrange
                )
            }
        }

        drawFooter()
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
