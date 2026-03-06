import Foundation
import SwiftData

@Model
final class CardGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }
}
