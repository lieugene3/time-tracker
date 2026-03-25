import Charts
import Foundation
import Observation
import SwiftData
import SwiftUI
import UserNotifications

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]
    @AppStorage(
        WeeklyRecapNotificationSettingsStore.isEnabledKey,
        store: DayActivityTrackerSharedDefaults.userDefaults
    ) private var isWeeklyRecapEnabled = false
    @State private var viewModel = ReportsViewModel()
    @State private var weeklyRecapAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var notificationErrorMessage: String?

    var body: some View {
        @Bindable var viewModel = viewModel
        let snapshot = viewModel.reportSnapshot(from: sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Report Range", selection: $viewModel.selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.title)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Report range")
                .onChange(of: viewModel.selectedPeriod) { _, period in
                    viewModel.handlePeriodSelection(period)
                }

                ReportOverviewCard(
                    dateRangeText: viewModel.dateRangeText(for: snapshot.range),
                    isEditable: viewModel.appliedPeriod == .custom,
                    onTap: viewModel.presentCustomRangeSheet
                )

                WeeklyRecapPreferenceCard(
                    isEnabled: isWeeklyRecapEnabled,
                    authorizationStatus: weeklyRecapAuthorizationStatus,
                    onEnable: enableWeeklyRecapNotifications,
                    onDisable: disableWeeklyRecapNotifications
                )

                ReportCard(title: "Category Share") {
                    if snapshot.totalTrackedDuration > 0 {
                        Chart(snapshot.summaries.filter { $0.totalDuration > 0 }) { summary in
                            SectorMark(
                                angle: .value("Total", summary.totalDuration),
                                innerRadius: .ratio(0.62),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Activity", summary.category.displayName))
                        }
                        .frame(height: 240)
                        .chartForegroundStyleScale(
                            domain: ReportChartPalette.domain,
                            range: ReportChartPalette.range
                        )
                        .chartLegend(.hidden)
                        .accessibilityLabel("Category share chart")
                    } else {
                        ReportEmptyState(message: "No tracked time falls inside the selected range.")
                    }
                }

                ReportTableCard(snapshot: snapshot)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.isShowingCustomRangeSheet) {
            CustomRangeSheet(viewModel: viewModel)
        }
        .task {
            await refreshWeeklyRecapStatus()
            if isWeeklyRecapEnabled {
                await WeeklyRecapNotificationCoordinator.syncImmediately(using: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshWeeklyRecapStatus()
                if isWeeklyRecapEnabled {
                    await WeeklyRecapNotificationCoordinator.syncImmediately(using: modelContext)
                }
            }
        }
        .alert("Unable to Configure Weekly Recap", isPresented: notificationErrorIsPresented) {
            Button("OK", role: .cancel) {
                notificationErrorMessage = nil
            }
        } message: {
            Text(notificationErrorMessage ?? "Something went wrong.")
        }
    }

    private var notificationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { notificationErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    notificationErrorMessage = nil
                }
            }
        )
    }

    private func enableWeeklyRecapNotifications() {
        Task {
            do {
                let isAuthorized = try await WeeklyRecapNotificationCoordinator.requestAuthorizationIfNeeded()
                await refreshWeeklyRecapStatus()

                guard isAuthorized else {
                    isWeeklyRecapEnabled = false
                    notificationErrorMessage = "Allow notifications for Day Activity Tracker in Settings to receive the weekly recap."
                    return
                }

                isWeeklyRecapEnabled = true
                await WeeklyRecapNotificationCoordinator.syncImmediately(using: modelContext)
            } catch {
                isWeeklyRecapEnabled = false
                notificationErrorMessage = error.localizedDescription
            }
        }
    }

    private func disableWeeklyRecapNotifications() {
        isWeeklyRecapEnabled = false
        WeeklyRecapNotificationCoordinator.removePendingRequests()
    }

    private func refreshWeeklyRecapStatus() async {
        weeklyRecapAuthorizationStatus = await WeeklyRecapNotificationCoordinator.authorizationStatus()
    }
}

private struct ReportOverviewCard: View {
    let dateRangeText: String
    let isEditable: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if isEditable {
                Button(action: onTap) {
                    dateRangeLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit custom range. \(dateRangeText)")
            } else {
                dateRangeLabel
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(dateRangeText)
            }
        }
    }

    private var dateRangeLabel: some View {
        Text(dateRangeText)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct WeeklyRecapPreferenceCard: View {
    let isEnabled: Bool
    let authorizationStatus: UNAuthorizationStatus
    let onEnable: () -> Void
    let onDisable: () -> Void

    private let activityLabels = ["Learn", "Exercise", "Personal", "Media"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weekly Recap")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }

            HStack(spacing: 8) {
                ForEach(activityLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: buttonAction) {
                Label(buttonTitle, systemImage: isEnabled ? "bell.slash.fill" : "bell.badge.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color(red: 0.08, green: 0.25, blue: 0.37))
            .accessibilityLabel(buttonTitle)

            if authorizationStatus == .denied {
                Label("Notifications are currently disabled for this app in system settings.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.84))
            }
        }
        .padding(18)
        .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var buttonTitle: String {
        isEnabled ? "Turn Off Weekly Recap" : "Enable Weekly Recap"
    }

    private var statusLabel: String {
        isEnabled ? "Mondays 8:00 AM" : "Optional"
    }

    private var descriptionText: String {
        if isEnabled {
            return "A polished Monday recap highlights last week's Learn, Exercise, Personal, and Media hours/day."
        }

        return "Get a polished weekly summary card at the start of each week with your core lifestyle averages."
    }

    private var background: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.18, blue: 0.31),
                Color(red: 0.13, green: 0.36, blue: 0.53),
                Color(red: 0.19, green: 0.55, blue: 0.66)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func buttonAction() {
        if isEnabled {
            onDisable()
        } else {
            onEnable()
        }
    }
}

private struct ReportCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ReportEmptyState: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to Chart")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

private enum ReportChartPalette {
    static let domain = ActivityCategory.allCases.map(\.displayName)
    static let range: [Color] = ActivityCategory.allCases.map { color(for: $0) }

    static func color(for category: ActivityCategory) -> Color {
        switch category {
        case .activeLearn:
            return .blue
        case .passiveLearn:
            return .teal
        case .media:
            return .indigo
        case .commuteTravel:
            return .orange
        case .social:
            return .pink
        case .work:
            return .green
        case .exercise:
            return .red
        case .sleep:
            return .cyan
        case .personal:
            return .brown
        }
    }
}

private struct ReportTableCard: View {
    let snapshot: ReportSnapshot

    private let averageColumnWidth: CGFloat = 58
    private let totalColumnWidth: CGFloat = 60
    private let percentageColumnWidth: CGFloat = 34

    var body: some View {
        ReportCard(title: "Details") {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Activity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Avg/day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: averageColumnWidth, alignment: .trailing)
                    Text("Total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: totalColumnWidth, alignment: .trailing)
                    Text("%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: percentageColumnWidth, alignment: .trailing)
                }

                Divider()
                    .gridCellColumns(4)

                ForEach(snapshot.summaries) { summary in
                    GridRow {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ReportChartPalette.color(for: summary.category))
                                .frame(width: 8, height: 8)

                            Text(summary.category.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }

                        Text(DurationFormatting.abbreviated(summary.averagePerDay))
                            .font(.footnote.monospacedDigit())
                            .frame(width: averageColumnWidth, alignment: .trailing)

                        Text(DurationFormatting.abbreviated(summary.totalDuration))
                            .font(.footnote.monospacedDigit())
                            .frame(width: totalColumnWidth, alignment: .trailing)

                        Text(PercentageFormatting.wholePercent(summary.percentage))
                            .font(.footnote.monospacedDigit())
                            .frame(width: percentageColumnWidth, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(summary.category.displayName), average per day \(DurationFormatting.abbreviated(summary.averagePerDay)), total \(DurationFormatting.abbreviated(summary.totalDuration)), \(PercentageFormatting.wholePercent(summary.percentage))."
                    )
                }
            }
        }
    }
}

@MainActor
private struct CustomRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ReportsViewModel

    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker(
                        "Start",
                        selection: $viewModel.customStartAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Custom range start")

                    DatePicker(
                        "End",
                        selection: $viewModel.customEndAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Custom range end")
                }

                Section {
                    Text("Future end values are clamped to the current time when you apply the range.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Custom Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelCustomRange()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        do {
                            try viewModel.applyCustomRange()
                            dismiss()
                        } catch let error as LocalizedError {
                            errorMessage = error.errorDescription ?? "Something went wrong."
                            isShowingError = true
                        } catch {
                            errorMessage = error.localizedDescription
                            isShowingError = true
                        }
                    }
                    .accessibilityLabel("Apply custom range")
                }
            }
            .alert("Unable to Apply Range", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {
                    isShowingError = false
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            "Today"
        case .week:
            "Week"
        case .month:
            "Month"
        case .custom:
            "Custom"
        }
    }

    var summaryTitle: String {
        switch self {
        case .today:
            "Today"
        case .week:
            "This Week"
        case .month:
            "This Month"
        case .custom:
            "Custom Range"
        }
    }

    var selection: ReportRangeSelection? {
        switch self {
        case .today:
            .today
        case .week:
            .week
        case .month:
            .month
        case .custom:
            nil
        }
    }
}

@MainActor
@Observable
final class ReportsViewModel {
    var selectedPeriod: ReportPeriod = .week
    var customStartAt: Date
    var customEndAt: Date
    var isShowingCustomRangeSheet = false

    private let reportService: ReportService
    private(set) var appliedPeriod: ReportPeriod = .week
    private var appliedSelection: ReportRangeSelection = .week

    init(reportService: ReportService? = nil, now: Date = .now) {
        let calendar = Calendar.dayActivityTracker
        self.reportService = reportService ?? ReportService()
        self.customStartAt = calendar.startOfDay(for: now)
        self.customEndAt = now
    }

    func handlePeriodSelection(_ period: ReportPeriod) {
        if period == .custom {
            isShowingCustomRangeSheet = true
            return
        }

        if let selection = period.selection {
            appliedPeriod = period
            appliedSelection = selection
        }
    }

    func presentCustomRangeSheet() {
        selectedPeriod = .custom
        isShowingCustomRangeSheet = true
    }

    func cancelCustomRange() {
        isShowingCustomRangeSheet = false
        selectedPeriod = appliedPeriod
    }

    func applyCustomRange() throws {
        let selection = ReportRangeSelection.custom(start: customStartAt, end: customEndAt)
        let resolvedRange = try reportService.resolveRange(for: selection)
        customStartAt = resolvedRange.start
        customEndAt = resolvedRange.end
        appliedSelection = .custom(start: resolvedRange.start, end: resolvedRange.end)
        appliedPeriod = .custom
        isShowingCustomRangeSheet = false
    }

    func reportSnapshot(from sessions: [ActivitySession]) -> ReportSnapshot {
        if let snapshot = try? reportService.makeReport(for: appliedSelection, sessions: sessions) {
            return snapshot
        }

        let fallbackRange = ReportTimeRange(start: .now, end: .now, dayCount: 1)
        let fallbackSummaries = ActivityCategory.allCases.map {
            ReportCategorySummary(
                category: $0,
                totalDuration: 0,
                averagePerDay: 0,
                percentage: 0
            )
        }
        return ReportSnapshot(
            range: fallbackRange,
            totalTrackedDuration: 0,
            summaries: fallbackSummaries
        )
    }

    func dateRangeText(for range: ReportTimeRange) -> String {
        "\(DateFormatting.mediumDate(range.start)) - \(DateFormatting.mediumDate(range.end))"
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(SampleData.previewContainer)
}
