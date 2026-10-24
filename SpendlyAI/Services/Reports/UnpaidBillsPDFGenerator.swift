import Foundation
import UIKit

struct UnpaidBillPrintEntry {
    let title: String
    let amount: Decimal
    let dueDate: Date
}

@MainActor
struct UnpaidBillsPDFGenerator {
    private let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private let margin: CGFloat = 48

    func makePDF(
        entries: [UnpaidBillPrintEntry],
        currencyCode: String,
        locale: Locale
    ) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: String(localized: "unpaid.title", locale: locale),
            kCGPDFContextAuthor as String: "SpendlyAI"
        ]

        return UIGraphicsPDFRenderer(bounds: pageBounds, format: format).pdfData { context in
            var cursorY: CGFloat = margin

            func beginPage() {
                context.beginPage()
                UIColor.white.setFill()
                UIRectFill(pageBounds)
                cursorY = margin
            }

            func drawText(
                _ text: String,
                in rect: CGRect,
                font: UIFont,
                alignment: NSTextAlignment = .left
            ) {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.lineBreakMode = .byTruncatingTail
                (text as NSString).draw(
                    in: rect,
                    withAttributes: [
                        .font: font,
                        .foregroundColor: UIColor.black,
                        .paragraphStyle: style
                    ]
                )
            }

            func drawHeader() {
                drawText(
                    String(localized: "unpaid.title", locale: locale),
                    in: CGRect(x: margin, y: cursorY, width: 400, height: 36),
                    font: .boldSystemFont(ofSize: 26)
                )
                cursorY += 40
                let generated = Date.now.formatted(
                    .dateTime.locale(locale).day().month(.wide).year().hour().minute()
                )
                drawText(
                    "\(String(localized: "Generated", locale: locale)): \(generated)",
                    in: CGRect(x: margin, y: cursorY, width: 400, height: 20),
                    font: .systemFont(ofSize: 10)
                )
                cursorY += 28

                let headerFont = UIFont.boldSystemFont(ofSize: 9)
                drawText("", in: CGRect(x: margin, y: cursorY, width: 24, height: 18), font: headerFont)
                drawText(
                    String(localized: "Date", locale: locale),
                    in: CGRect(x: margin + 32, y: cursorY, width: 80, height: 18),
                    font: headerFont
                )
                drawText(
                    String(localized: "Title", locale: locale),
                    in: CGRect(x: margin + 116, y: cursorY, width: 230, height: 18),
                    font: headerFont
                )
                drawText(
                    String(localized: "Amount", locale: locale),
                    in: CGRect(x: margin + 350, y: cursorY, width: 149, height: 18),
                    font: headerFont,
                    alignment: .right
                )
                cursorY += 22
            }

            beginPage()
            drawHeader()

            for entry in entries {
                if cursorY + 30 > pageBounds.height - margin {
                    beginPage()
                    drawHeader()
                }

                let checkbox = UIBezierPath(rect: CGRect(x: margin + 2, y: cursorY + 2, width: 12, height: 12))
                UIColor.black.setStroke()
                checkbox.lineWidth = 1
                checkbox.stroke()

                let rowFont = UIFont.systemFont(ofSize: 10)
                drawText(
                    entry.dueDate.formatted(.dateTime.locale(locale).day().month().year()),
                    in: CGRect(x: margin + 32, y: cursorY, width: 80, height: 18),
                    font: rowFont
                )
                drawText(
                    entry.title,
                    in: CGRect(x: margin + 116, y: cursorY, width: 230, height: 18),
                    font: rowFont
                )
                drawText(
                    MoneyFormatter.string(from: entry.amount, currencyCode: currencyCode, locale: locale),
                    in: CGRect(x: margin + 350, y: cursorY, width: 149, height: 18),
                    font: rowFont,
                    alignment: .right
                )

                cursorY += 24
                let divider = UIBezierPath()
                divider.move(to: CGPoint(x: margin, y: cursorY))
                divider.addLine(to: CGPoint(x: pageBounds.width - margin, y: cursorY))
                UIColor(white: 0.85, alpha: 1).setStroke()
                divider.lineWidth = 0.5
                divider.stroke()
                cursorY += 6
            }

            let total = entries.reduce(Decimal.zero) { $0 + $1.amount }
            if cursorY + 36 > pageBounds.height - margin {
                beginPage()
            }
            drawText(
                String(localized: "unpaid.summary.total", locale: locale),
                in: CGRect(x: margin + 250, y: cursorY + 8, width: 100, height: 20),
                font: .boldSystemFont(ofSize: 11),
                alignment: .right
            )
            drawText(
                MoneyFormatter.string(from: total, currencyCode: currencyCode, locale: locale),
                in: CGRect(x: margin + 350, y: cursorY + 8, width: 149, height: 20),
                font: .boldSystemFont(ofSize: 11),
                alignment: .right
            )
        }
    }
}
