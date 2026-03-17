import Foundation
import SwiftData

@MainActor
enum SampleData {
    static var previewContainer: ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ActivitySession.self,
            SavedSubActivity.self,
            configurations: configuration
        )

        insertPreviewData(into: container.mainContext)
        return container
    }

    static func insertPreviewData(into context: ModelContext, now: Date = .now) {
        let savedItems = [
            SavedSubActivity(parentCategory: .activeLearn, name: "SwiftUI", createdAt: now.addingTimeInterval(-86_400), lastUsedAt: now.addingTimeInterval(-4_000)),
            SavedSubActivity(parentCategory: .passiveLearn, name: "Podcasts", createdAt: now.addingTimeInterval(-172_800), lastUsedAt: now.addingTimeInterval(-12_000))
        ]

        let sessions = [
            ActivitySession(category: .sleep, startAt: now.addingTimeInterval(-86_400), endAt: now.addingTimeInterval(-79_200), createdAt: now.addingTimeInterval(-86_400), updatedAt: now.addingTimeInterval(-79_200)),
            ActivitySession(category: .work, startAt: now.addingTimeInterval(-54_000), endAt: now.addingTimeInterval(-46_800), createdAt: now.addingTimeInterval(-54_000), updatedAt: now.addingTimeInterval(-46_800)),
            ActivitySession(category: .exercise, startAt: now.addingTimeInterval(-43_200), endAt: now.addingTimeInterval(-40_500), createdAt: now.addingTimeInterval(-43_200), updatedAt: now.addingTimeInterval(-40_500)),
            ActivitySession(category: .media, startAt: now.addingTimeInterval(-21_600), endAt: now.addingTimeInterval(-18_000), createdAt: now.addingTimeInterval(-21_600), updatedAt: now.addingTimeInterval(-18_000)),
            ActivitySession(category: .work, startAt: now.addingTimeInterval(-14_400), endAt: now.addingTimeInterval(-10_800), createdAt: now.addingTimeInterval(-14_400), updatedAt: now.addingTimeInterval(-10_800)),
            ActivitySession(category: .social, startAt: now.addingTimeInterval(-9_000), endAt: now.addingTimeInterval(-7_200), createdAt: now.addingTimeInterval(-9_000), updatedAt: now.addingTimeInterval(-7_200)),
            ActivitySession(category: .activeLearn, subActivityName: "SwiftUI", startAt: now.addingTimeInterval(-4_500), endAt: now.addingTimeInterval(-2_700), createdAt: now.addingTimeInterval(-4_500), updatedAt: now.addingTimeInterval(-2_700)),
            ActivitySession(category: .personal, startAt: now.addingTimeInterval(-2_400), endAt: now.addingTimeInterval(-1_500), createdAt: now.addingTimeInterval(-2_400), updatedAt: now.addingTimeInterval(-1_500)),
            ActivitySession(category: .passiveLearn, subActivityName: "Podcasts", startAt: now.addingTimeInterval(-1_200), createdAt: now.addingTimeInterval(-1_200), updatedAt: now.addingTimeInterval(-1_200))
        ]

        savedItems.forEach(context.insert)
        sessions.forEach(context.insert)
    }
}
