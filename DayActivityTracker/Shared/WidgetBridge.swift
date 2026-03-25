import ActivityKit
import Foundation
import SwiftData
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

enum DayActivityTrackerWidgetBridge {
    static let snapshotKey = "widget.currentSessionSnapshot"
    static let urlScheme = "dayactivitytracker"

    static let appGroupIdentifier: String = {
        let candidates = candidateAppGroupIdentifiers()

        if let validGroup = candidates.first(where: hasAccessibleContainer(for:)) {
            return validGroup
        }

        if let firstCandidate = candidates.first {
            return firstCandidate
        }

        fatalError("Unable to resolve App Group identifier from Info.plist or bundle identifier.")
    }()

    private static func candidateAppGroupIdentifiers() -> [String] {
        var candidates: [String] = []

        if let plistGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           plistGroup.isEmpty == false {
            candidates.append(plistGroup)
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier, bundleIdentifier.isEmpty == false else {
            return candidates
        }

        if Bundle.main.object(forInfoDictionaryKey: "NSExtension") != nil {
            let components = bundleIdentifier.split(separator: ".")
            if components.count > 1 {
                candidates.append("group.\(components.dropLast().joined(separator: ".")).shared")
            }
        }

        candidates.append("group.\(bundleIdentifier).shared")
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private static func hasAccessibleContainer(for identifier: String) -> Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }
}

enum DayActivityTrackerSharedDefaults {
    static let userDefaults = UserDefaults(suiteName: DayActivityTrackerWidgetBridge.appGroupIdentifier) ?? .standard
}

enum DayActivityTrackerSharedStore {
    private static let schema = Schema([
        ActivitySession.self,
        SavedSubActivity.self
    ])

    static let sharedModelContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            "DayActivityTracker",
            schema: schema,
            groupContainer: .identifier(DayActivityTrackerWidgetBridge.appGroupIdentifier),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create the shared model container: \(error)")
        }
    }()

    @MainActor
    static func migrateLegacyStoreIfNeeded() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSExtension") == nil else {
            return
        }

        let legacyConfiguration = ModelConfiguration(
            "DayActivityTracker",
            schema: schema,
            cloudKitDatabase: .none
        )

        guard let legacyContainer = try? ModelContainer(for: schema, configurations: [legacyConfiguration]) else {
            return
        }

        let sharedContext = sharedModelContainer.mainContext
        let legacyContext = legacyContainer.mainContext

        let existingSessionIDs = Set((try? sharedContext.fetch(FetchDescriptor<ActivitySession>()).map(\.id)) ?? [])
        let existingSavedSubActivityIDs = Set((try? sharedContext.fetch(FetchDescriptor<SavedSubActivity>()).map(\.id)) ?? [])
        let legacySavedSubActivities = (try? legacyContext.fetch(FetchDescriptor<SavedSubActivity>())) ?? []
        let legacySessions = (try? legacyContext.fetch(FetchDescriptor<ActivitySession>())) ?? []

        var insertedCount = 0

        for legacySubActivity in legacySavedSubActivities where existingSavedSubActivityIDs.contains(legacySubActivity.id) == false {
            sharedContext.insert(
                SavedSubActivity(
                    id: legacySubActivity.id,
                    parentCategory: legacySubActivity.parentCategory,
                    name: legacySubActivity.name,
                    createdAt: legacySubActivity.createdAt,
                    lastUsedAt: legacySubActivity.lastUsedAt,
                    isArchived: legacySubActivity.isArchived
                )
            )
            insertedCount += 1
        }

        for legacySession in legacySessions where existingSessionIDs.contains(legacySession.id) == false {
            sharedContext.insert(
                ActivitySession(
                    id: legacySession.id,
                    category: legacySession.category,
                    subActivityName: legacySession.subActivityName,
                    startAt: legacySession.startAt,
                    endAt: legacySession.endAt,
                    createdAt: legacySession.createdAt,
                    updatedAt: legacySession.updatedAt
                )
            )
            insertedCount += 1
        }

        guard insertedCount > 0 else {
            return
        }

        try? sharedContext.save()
    }
}

struct WidgetSessionSnapshot: Codable, Hashable {
    let categoryRawValue: String
    let subActivityName: String?
    let startAt: Date

    var category: ActivityCategory {
        ActivityCategory(rawValue: categoryRawValue) ?? .personal
    }
}

extension WidgetSessionSnapshot {
    init(session: ActivitySession) {
        self.init(
            categoryRawValue: session.category.rawValue,
            subActivityName: session.subActivityName,
            startAt: session.startAt
        )
    }
}

enum WidgetSessionSnapshotStore {
    static func load() -> WidgetSessionSnapshot? {
        guard let data = userDefaults.data(forKey: DayActivityTrackerWidgetBridge.snapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSessionSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSessionSnapshot?) {
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: DayActivityTrackerWidgetBridge.snapshotKey)
        } else {
            userDefaults.removeObject(forKey: DayActivityTrackerWidgetBridge.snapshotKey)
        }
    }

    private static let userDefaults = DayActivityTrackerSharedDefaults.userDefaults
}

enum DayActivityLiveActivitySettingsStore {
    static let isEnabledKey = "liveActivity.isEnabled"

    static var isEnabled: Bool {
        get { DayActivityTrackerSharedDefaults.userDefaults.bool(forKey: isEnabledKey) }
        set { DayActivityTrackerSharedDefaults.userDefaults.set(newValue, forKey: isEnabledKey) }
    }
}

enum WeeklyRecapNotificationSettingsStore {
    static let isEnabledKey = "weeklyRecapNotification.isEnabled"

    static var isEnabled: Bool {
        get { DayActivityTrackerSharedDefaults.userDefaults.bool(forKey: isEnabledKey) }
        set { DayActivityTrackerSharedDefaults.userDefaults.set(newValue, forKey: isEnabledKey) }
    }
}

struct DayActivityLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let snapshot: WidgetSessionSnapshot?
    }

    let displayName: String

    init(displayName: String = "Quick Activity") {
        self.displayName = displayName
    }
}

enum DayActivityLiveActivityBridge {
    static var areActivitiesAuthorized: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func contentState(snapshot: WidgetSessionSnapshot?) -> DayActivityLiveActivityAttributes.ContentState {
        DayActivityLiveActivityAttributes.ContentState(snapshot: snapshot)
    }

    @available(iOS 16.2, *)
    static func content(snapshot: WidgetSessionSnapshot?) -> ActivityContent<DayActivityLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: contentState(snapshot: snapshot),
            staleDate: nil,
            relevanceScore: 100
        )
    }

    @available(iOS 16.2, *)
    static func updateExistingActivities(snapshot: WidgetSessionSnapshot?) async {
        let content = content(snapshot: snapshot)
        for activity in Activity<DayActivityLiveActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}

@MainActor
enum DayActivityActivitySurfaceCoordinator {
    static func sync(using context: ModelContext) {
        sync(snapshot: currentSnapshot(in: context))
    }

    static func sync(snapshot: WidgetSessionSnapshot?) {
        Task {
            await syncImmediately(snapshot: snapshot)
        }
    }

    static func syncImmediately(snapshot: WidgetSessionSnapshot?) async {
        WidgetSessionSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        guard #available(iOS 16.2, *) else {
            return
        }

        let isEnabled = DayActivityLiveActivitySettingsStore.isEnabled
        await DayActivityLiveActivityCoordinator.sync(snapshot: snapshot, isEnabled: isEnabled)
    }

    private static func currentSnapshot(in context: ModelContext) -> WidgetSessionSnapshot? {
        let descriptor = FetchDescriptor<ActivitySession>(
            sortBy: [SortDescriptor(\.startAt, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.first(where: \.isActive).map(WidgetSessionSnapshot.init(session:))
    }
}

@MainActor
enum DayActivityLiveActivityCoordinator {
    static func sync(snapshot: WidgetSessionSnapshot?, isEnabled: Bool) async {
        guard #available(iOS 16.2, *) else {
            return
        }

        let activities = Activity<DayActivityLiveActivityAttributes>.activities

        guard isEnabled else {
            await end(activities: activities)
            return
        }

        guard DayActivityLiveActivityBridge.areActivitiesAuthorized else {
            await end(activities: activities)
            return
        }

        let content = DayActivityLiveActivityBridge.content(snapshot: snapshot)

        if activities.isEmpty {
            do {
                _ = try Activity<DayActivityLiveActivityAttributes>.request(
                    attributes: DayActivityLiveActivityAttributes(),
                    content: content
                )
            } catch {
                // Leave the preference enabled and try again on the next foreground or session change.
            }
            return
        }

        for activity in activities {
            await activity.update(content)
        }
    }

    @available(iOS 16.2, *)
    private static func end(activities: [Activity<DayActivityLiveActivityAttributes>]) async {
        guard activities.isEmpty == false else {
            return
        }

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

enum WeeklyRecapMetricKind: String, CaseIterable, Identifiable {
    case learn
    case exercise
    case personal
    case media

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn:
            "Learn"
        case .exercise:
            "Exercise"
        case .personal:
            "Personal"
        case .media:
            "Media"
        }
    }

    var symbolName: String {
        switch self {
        case .learn:
            "brain.head.profile"
        case .exercise:
            "figure.run"
        case .personal:
            "heart.fill"
        case .media:
            "play.rectangle.fill"
        }
    }
}

struct WeeklyRecapMetric: Identifiable, Hashable {
    let kind: WeeklyRecapMetricKind
    let totalDuration: TimeInterval
    let averagePerDay: TimeInterval

    var id: WeeklyRecapMetricKind { kind }
    var title: String { kind.title }
    var symbolName: String { kind.symbolName }
}

struct WeeklyRecapSummary: Hashable {
    let deliveryDate: Date
    let weekStart: Date
    let weekEnd: Date
    let metrics: [WeeklyRecapMetric]

    var dateRangeText: String {
        DateFormatting.weeklyRecapRange(
            start: weekStart,
            end: weekEnd.addingTimeInterval(-1)
        )
    }

    var bodyText: String {
        metrics
            .map { "\($0.title) \(DurationFormatting.hoursPerDay($0.totalDuration, dayCount: 7))" }
            .joined(separator: "\n")
    }
}

private extension UNAuthorizationStatus {
    var supportsWeeklyRecapNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }
}

@MainActor
enum WeeklyRecapNotificationCoordinator {
    static let requestIdentifier = "weekly-recap.notification"

    private static let deliveryWeekday = 2
    private static let deliveryHour = 8
    private static let deliveryMinute = 0
    private static let threadIdentifier = "weekly-recap"

    static func sync(using context: ModelContext) {
        Task {
            await syncImmediately(using: context)
        }
    }

    static func syncImmediately(using context: ModelContext) async {
        guard WeeklyRecapNotificationSettingsStore.isEnabled else {
            removePendingRequests()
            return
        }

        let authorizationStatus = await authorizationStatus()
        guard authorizationStatus.supportsWeeklyRecapNotifications else {
            removePendingRequests()
            return
        }

        let summary = makeSummary(
            sessions: allSessions(in: context),
            now: Date()
        )

        let content = makeContent(for: summary)
        let triggerDateComponents = Calendar.dayActivityTracker.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: summary.deliveryDate
        )
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        )

        let center = UNUserNotificationCenter.current()
        removePendingRequests()

        do {
            try await center.add(request)
        } catch {
            // Keep the preference enabled and try again after the next session change or app launch.
        }
    }

    static func requestAuthorizationIfNeeded() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        @unknown default:
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func removePendingRequests() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
    }

    private static func allSessions(in context: ModelContext) -> [ActivitySession] {
        let descriptor = FetchDescriptor<ActivitySession>(
            sortBy: [SortDescriptor(\.startAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func makeSummary(
        sessions: [ActivitySession],
        now: Date,
        calendar: Calendar = .dayActivityTracker
    ) -> WeeklyRecapSummary {
        let deliveryDate = nextDeliveryDate(after: now, calendar: calendar)
        let weekEnd = calendar.startOfDay(for: deliveryDate)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) ?? weekEnd
        let accumulationEnd = min(now, weekEnd)

        var totalsByMetric: [WeeklyRecapMetricKind: TimeInterval] = [:]

        for session in sessions {
            let sessionEnd = session.effectiveEndDate(now: now)
            let overlapStart = max(session.startAt, weekStart)
            let overlapEnd = min(sessionEnd, accumulationEnd)
            guard overlapEnd > overlapStart,
                  let metric = metricKind(for: session.category) else {
                continue
            }

            var currentStart = overlapStart
            while currentStart < overlapEnd {
                let nextDayStart = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: currentStart)
                ) ?? overlapEnd
                let segmentEnd = min(overlapEnd, nextDayStart)
                totalsByMetric[metric, default: 0] += segmentEnd.timeIntervalSince(currentStart)
                currentStart = segmentEnd
            }
        }

        let metrics = WeeklyRecapMetricKind.allCases.map { metric in
            let totalDuration = totalsByMetric[metric] ?? 0
            return WeeklyRecapMetric(
                kind: metric,
                totalDuration: totalDuration,
                averagePerDay: totalDuration / 7
            )
        }

        return WeeklyRecapSummary(
            deliveryDate: deliveryDate,
            weekStart: weekStart,
            weekEnd: weekEnd,
            metrics: metrics
        )
    }

    private static func nextDeliveryDate(
        after now: Date,
        calendar: Calendar = .dayActivityTracker
    ) -> Date {
        var components = DateComponents()
        components.weekday = deliveryWeekday
        components.hour = deliveryHour
        components.minute = deliveryMinute
        components.second = 0

        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? now.addingTimeInterval(7 * 24 * 60 * 60)
    }

    private static func metricKind(for category: ActivityCategory) -> WeeklyRecapMetricKind? {
        switch category {
        case .activeLearn, .passiveLearn:
            .learn
        case .exercise:
            .exercise
        case .personal:
            .personal
        case .media:
            .media
        default:
            nil
        }
    }

    private static func makeContent(for summary: WeeklyRecapSummary) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Recap"
        content.subtitle = summary.dateRangeText
        content.body = summary.bodyText
        content.sound = .default
        content.threadIdentifier = threadIdentifier
        content.interruptionLevel = .passive

        if let attachment = makeAttachment(for: summary) {
            content.attachments = [attachment]
        }

        return content
    }

    private static func makeAttachment(for summary: WeeklyRecapSummary) -> UNNotificationAttachment? {
        let renderer = ImageRenderer(
            content: WeeklyRecapNotificationCard(summary: summary)
        )
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage,
              let pngData = image.pngData() else {
            return nil
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-recap-card.png")
        try? FileManager.default.removeItem(at: fileURL)

        do {
            try pngData.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "weekly-recap-card", url: fileURL)
        } catch {
            return nil
        }
    }
}

private struct WeeklyRecapNotificationCard: View {
    let summary: WeeklyRecapSummary

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.16, blue: 0.29),
                    Color(red: 0.12, green: 0.35, blue: 0.55),
                    Color(red: 0.33, green: 0.59, blue: 0.69)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 220, height: 220)
                .offset(x: 250, y: -150)

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .frame(width: 170, height: 170)
                .offset(x: -260, y: 150)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Week in Review")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(summary.dateRangeText)
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.82))

                        Text("Hours per day across Learn, Exercise, Personal, and Media.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(summary.metrics) { metric in
                        WeeklyRecapMetricTile(metric: metric)
                    }
                }
            }
            .padding(30)
        }
        .frame(width: 720, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

private struct WeeklyRecapMetricTile: View {
    let metric: WeeklyRecapMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(metric.title, systemImage: metric.symbolName)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(DurationFormatting.hoursPerDay(metric.totalDuration, dayCount: 7))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Average this week")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

enum WidgetActivitySelectionLink {
    static func url(for category: ActivityCategory) -> URL {
        var components = URLComponents()
        components.scheme = DayActivityTrackerWidgetBridge.urlScheme
        components.host = "select"
        components.queryItems = [
            URLQueryItem(name: "category", value: category.rawValue)
        ]

        return components.url ?? URL(string: "dayactivitytracker://select")!
    }

    static func selectedCategory(from url: URL) -> ActivityCategory? {
        guard url.scheme?.lowercased() == DayActivityTrackerWidgetBridge.urlScheme,
              url.host == "select" else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawValue = components?.queryItems?.first { $0.name == "category" }?.value
        return rawValue.flatMap(ActivityCategory.init(rawValue:))
    }
}
