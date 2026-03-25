import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

extension ActivityCategory: AppEnum {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Activity")

    static var caseDisplayRepresentations: [ActivityCategory: DisplayRepresentation] = [
        .activeLearn: DisplayRepresentation(title: "Active Learn"),
        .passiveLearn: DisplayRepresentation(title: "Passive Learn"),
        .media: DisplayRepresentation(title: "Media"),
        .commuteTravel: DisplayRepresentation(title: "Commute/Travel"),
        .social: DisplayRepresentation(title: "Social"),
        .work: DisplayRepresentation(title: "Work"),
        .exercise: DisplayRepresentation(title: "Exercise"),
        .sleep: DisplayRepresentation(title: "Sleep"),
        .personal: DisplayRepresentation(title: "Personal")
    ]
}

struct SelectActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Activity"
    static var description = IntentDescription("Switches the current activity directly from the widget.")
    static var openAppWhenRun = false

    @Parameter(title: "Activity")
    var category: ActivityCategory

    init() {}

    init(category: ActivityCategory) {
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = DayActivityTrackerSharedStore.sharedModelContainer.mainContext
        let sessionService = SessionService()
        let session = try sessionService.selectActivity(category: category, in: context)
        await DayActivityActivitySurfaceCoordinator.syncImmediately(
            snapshot: WidgetSessionSnapshot(session: session)
        )
        await WeeklyRecapNotificationCoordinator.syncImmediately(using: context)
        return .result()
    }
}

struct DayActivityCompactEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSessionSnapshot?
}

struct DayActivityCompactProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayActivityCompactEntry {
        DayActivityCompactEntry(date: .now, snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayActivityCompactEntry) -> Void) {
        completion(DayActivityCompactEntry(date: .now, snapshot: WidgetSessionSnapshotStore.load() ?? previewSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayActivityCompactEntry>) -> Void) {
        let entry = DayActivityCompactEntry(date: .now, snapshot: WidgetSessionSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private var previewSnapshot: WidgetSessionSnapshot {
        WidgetSessionSnapshot(
            categoryRawValue: ActivityCategory.work.rawValue,
            subActivityName: "Sprint planning",
            startAt: .now.addingTimeInterval(-65 * 60)
        )
    }
}

struct DayActivityCompactWidget: Widget {
    static let kind = "DayActivityCompactWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DayActivityCompactProvider()) { entry in
            DayActivityCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Activity")
        .description("See your current activity and switch it without opening the app.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct DayActivityLockScreenWidget: Widget {
    static let kind = "DayActivityLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DayActivityCompactProvider()) { entry in
            DayActivityLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Activity")
        .description("See your current activity and quick-switch from the lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct DayActivityCompactWidgetView: View {
    let entry: DayActivityCompactEntry

    var body: some View {
        DayActivityQuickSwitchSurface(snapshot: entry.snapshot)
            .containerBackground(for: .widget) {
                Color.clear
            }
    }
}

struct DayActivityQuickSwitchSurface: View {
    let snapshot: WidgetSessionSnapshot?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            currentActivitySection

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(ActivityCategory.allCases) { category in
                    Button(intent: SelectActivityIntent(category: category)) {
                        Text(category.widgetShortLabel)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(.horizontal, 4)
                            .foregroundStyle(isCurrent(category) ? Color.accentColor : Color.primary)
                            .background(chipBackground(for: category))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isCurrent(category) ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: category))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            backgroundView
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    @ViewBuilder
    private var currentActivitySection: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.category.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("Since \(DateFormatting.shortTime(snapshot.startAt))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text("No current activity")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
    }

    private func chipBackground(for category: ActivityCategory) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isCurrent(category)
                    ? Color.accentColor.opacity(0.16)
                    : Color(uiColor: .secondarySystemBackground).opacity(0.82)
            )
    }

    private func isCurrent(_ category: ActivityCategory) -> Bool {
        snapshot?.category == category
    }

    private func accessibilityLabel(for category: ActivityCategory) -> String {
        if isCurrent(category) {
            return "\(category.displayName), current activity"
        }

        return "Switch to \(category.displayName)"
    }

    private var backgroundView: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.14),
                    Color.indigo.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 118, height: 118)
                .offset(x: 56, y: -62)

            Circle()
                .fill(Color.indigo.opacity(0.10))
                .frame(width: 92, height: 92)
                .offset(x: -58, y: 60)
        }
    }
}

struct DayActivityLockScreenWidgetView: View {
    let entry: DayActivityCompactEntry

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(ActivityCategory.allCases) { category in
                    Button(intent: SelectActivityIntent(category: category)) {
                        Image(systemName: category.symbolName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 18)
                            .foregroundStyle(isCurrent(category) ? Color.accentColor : Color.primary)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        isCurrent(category)
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.primary.opacity(0.08)
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        isCurrent(category)
                                            ? Color.accentColor.opacity(0.35)
                                            : Color.primary.opacity(0.12),
                                        lineWidth: 0.75
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lockScreenAccessibilityLabel(for: category))
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let snapshot = entry.snapshot {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label(snapshot.category.displayName, systemImage: snapshot.category.symbolName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(DateFormatting.shortTime(snapshot.startAt))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text("No current activity")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
    }

    private func isCurrent(_ category: ActivityCategory) -> Bool {
        entry.snapshot?.category == category
    }

    private func lockScreenAccessibilityLabel(for category: ActivityCategory) -> String {
        if isCurrent(category) {
            return "\(category.displayName), current activity"
        }

        return "Switch to \(category.displayName)"
    }
}

struct DayActivityLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityLiveActivityAttributes.self) { context in
            DayActivityLiveActivityView(snapshot: context.state.snapshot)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    DayActivityLiveActivityView(snapshot: context.state.snapshot)
                        .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: context.state.snapshot?.category.symbolName ?? "clock.fill")
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                if let snapshot = context.state.snapshot {
                    Text(DateFormatting.shortTime(snapshot.startAt))
                        .font(.caption2.monospacedDigit())
                } else {
                    Image(systemName: "ellipsis")
                }
            } minimal: {
                Image(systemName: context.state.snapshot?.category.symbolName ?? "clock.fill")
            }
        }
    }
}

struct DayActivityLiveActivityView: View {
    let snapshot: WidgetSessionSnapshot?

    var body: some View {
        DayActivityQuickSwitchSurface(snapshot: snapshot)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }
}

@main
struct DayActivityTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayActivityCompactWidget()
        DayActivityLockScreenWidget()
        DayActivityLiveActivityWidget()
    }
}
