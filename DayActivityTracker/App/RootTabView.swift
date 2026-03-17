import SwiftUI

enum RootTab: Hashable {
    case history
    case home
    case reports
}

struct RootTabView: View {
    @State private var selection: RootTab = .home

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
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.previewContainer)
}
