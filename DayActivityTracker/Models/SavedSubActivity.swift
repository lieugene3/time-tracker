import Foundation
import SwiftData

@Model
final class SavedSubActivity {
    @Attribute(.unique) var id: UUID
    var parentCategoryRaw: String
    var name: String
    var createdAt: Date
    var lastUsedAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        parentCategory: ActivityCategory,
        name: String,
        createdAt: Date = .now,
        lastUsedAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.parentCategoryRaw = parentCategory.rawValue
        self.name = name
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isArchived = isArchived
    }

    var parentCategory: ActivityCategory {
        get { ActivityCategory(rawValue: parentCategoryRaw) ?? .activeLearn }
        set { parentCategoryRaw = newValue.rawValue }
    }
}
