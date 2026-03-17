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
            ActivitySession(category: .work, startAt: now.addingTimeInterval(-7_200), endAt: now.addingTimeInterval(-3_600), createdAt: now.addingTimeInterval(-7_200), updatedAt: now.addingTimeInterval(-3_600)),
            ActivitySession(category: .exercise, startAt: now.addingTimeInterval(-3_000), endAt: now.addingTimeInterval(-1_800), createdAt: now.addingTimeInterval(-3_000), updatedAt: now.addingTimeInterval(-1_800)),
            ActivitySession(category: .activeLearn, subActivityName: "SwiftUI", startAt: now.addingTimeInterval(-1_200), createdAt: now.addingTimeInterval(-1_200), updatedAt: now.addingTimeInterval(-1_200))
        ]

        savedItems.forEach(context.insert)
        sessions.forEach(context.insert)
    }
}
