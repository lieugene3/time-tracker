import SwiftData
import SwiftUI

@main
struct DayActivityTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    DayActivityTrackerSharedStore.migrateLegacyStoreIfNeeded()
                    await WeeklyRecapNotificationCoordinator.syncImmediately(
                        using: DayActivityTrackerSharedStore.sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(DayActivityTrackerSharedStore.sharedModelContainer)
    }
}
