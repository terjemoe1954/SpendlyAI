import Foundation
import SwiftData

@Model
final class CustomCategory {
    var name: String
    var systemImage: String
    var createdAt: Date

    init(name: String, systemImage: String = "tag", createdAt: Date = .now) {
        self.name = name
        self.systemImage = systemImage
        self.createdAt = createdAt
    }
}
