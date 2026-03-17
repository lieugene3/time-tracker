import Foundation
import SwiftData

@Model
final class ActivitySession {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var subActivityName: String?
    var startAt: Date
    var endAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: ActivityCategory,
        subActivityName: String? = nil,
        startAt: Date,
        endAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.subActivityName = subActivityName
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var isActive: Bool {
        endAt == nil
    }

    func effectiveEndDate(now: Date) -> Date {
        endAt ?? now
    }

    func duration(now: Date) -> TimeInterval {
        max(0, effectiveEndDate(now: now).timeIntervalSince(startAt))
    }
}
