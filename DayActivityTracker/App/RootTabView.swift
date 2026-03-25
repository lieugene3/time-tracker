import SwiftData
import SwiftUI

enum RootTab: Hashable {
    case history
    case home
    case reports
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]
    @AppStorage(
        DayActivityLiveActivitySettingsStore.isEnabledKey,
        store: DayActivityTrackerSharedDefaults.userDefaults
    ) private var isLiveActivityEnabled = false
    @State private var selection: RootTab = .home
    @State private var widgetActionErrorMessage: String?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(RootTab.history)

            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(RootTab.home)

            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Reports", systemImage: "chart.bar.xaxis")
            }
            .tag(RootTab.reports)
        }
        .task(id: widgetSnapshotSyncToken) {
            syncActivitySurfaces()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            syncActivitySurfaces()
        }
        .alert("Unable to Update Activity", isPresented: widgetActionErrorIsPresented) {
            Button("OK", role: .cancel) {
                widgetActionErrorMessage = nil
            }
        } message: {
            Text(widgetActionErrorMessage ?? "Something went wrong.")
        }
    }

    private var widgetSnapshotSyncToken: String {
        let sessionToken = sessions.map { session in
            let endToken = session.endAt?.timeIntervalSinceReferenceDate ?? -1
            let subActivityToken = session.subActivityName ?? ""
            return [
                session.id.uuidString,
                session.categoryRaw,
                subActivityToken,
                String(session.startAt.timeIntervalSinceReferenceDate),
                String(session.updatedAt.timeIntervalSinceReferenceDate),
                String(endToken)
            ].joined(separator: "-")
        }
        .joined(separator: "|")

        return "\(sessionToken)-live-\(isLiveActivityEnabled)"
    }

    private var widgetActionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { widgetActionErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    widgetActionErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        guard let category = WidgetActivitySelectionLink.selectedCategory(from: url) else {
            return
        }

        selection = .home

        do {
            try SessionService().selectActivity(category: category, in: modelContext)
        } catch let error as LocalizedError {
            widgetActionErrorMessage = error.errorDescription ?? "Something went wrong."
        } catch {
            widgetActionErrorMessage = error.localizedDescription
        }
    }

    private func syncActivitySurfaces() {
        DayActivityActivitySurfaceCoordinator.sync(using: modelContext)
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.previewContainer)
}
