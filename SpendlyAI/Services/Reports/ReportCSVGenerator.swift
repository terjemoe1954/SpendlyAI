import Foundation

struct ReportCSVEntry: Equatable, Sendable {
    enum EntryType: String, Sendable {
        case expense
        case income
    }

    let type: EntryType
    let date: Date
    let description: String
    let category: String
    let amount: Decimal
    let currencyCode: String
}

struct ReportCSVGenerator {
    func makeCSV(entries: [ReportCSVEntry]) -> Data {
        let header = ["type", "date", "description", "category", "amount", "currency"]
        let sortedEntries = entries.sorted {
            if $0.date == $1.date {
                return $0.description.localizedStandardCompare($1.description) == .orderedAscending
            }
            return $0.date < $1.date
        }
        let rows = sortedEntries.map { entry in
            [
                entry.type.rawValue,
                Self.dateFormatter.string(from: entry.date),
                entry.description,
                entry.category,
                NSDecimalNumber(decimal: entry.amount).stringValue,
                entry.currencyCode
            ]
        }

        let csv = ([header] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
        return Data(csv.utf8)
    }

    private func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
