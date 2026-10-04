import Foundation
import SwiftUI

enum PaymentStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case withdrawn
    case settled
    case overdue

    func effectiveStatus(dueDate: Date?, now: Date = .now, calendar: Calendar = .current) -> PaymentStatus {
        guard self == .pending, let dueDate else { return self }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now) ? .overdue : .pending
    }

    func titleKey(for kind: PaymentKind) -> LocalizedStringKey {
        switch self {
        case .pending:
            "paymentStatus.pending"
        case .withdrawn:
            "paymentStatus.withdrawn"
        case .settled:
            kind == .income ? "paymentStatus.received" : "paymentStatus.paid"
        case .overdue:
            "paymentStatus.overdue"
        }
    }

    var displayColor: Color {
        switch self {
        case .pending:
            .secondary
        case .withdrawn:
            .orange
        case .settled:
            .green
        case .overdue:
            .red
        }
    }
}

enum PaymentKind: Sendable {
    case expense
    case income
}
