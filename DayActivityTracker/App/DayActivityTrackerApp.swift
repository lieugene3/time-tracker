import SwiftData
import SwiftUI

@main
struct DayActivityTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [ActivitySession.self, SavedSubActivity.self])
    }
}
