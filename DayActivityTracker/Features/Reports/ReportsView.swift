import Charts
import Foundation
import Observation
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]
    @State private var viewModel = ReportsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let snapshot = viewModel.reportSnapshot(from: sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Reports")
                    .font(.title.weight(.semibold))

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

                if viewModel.appliedPeriod == .custom {
                    Button("Edit Custom Range") {
                        viewModel.presentCustomRangeSheet()
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel("Edit custom range")
                }

                ReportOverviewCard(
                    title: viewModel.appliedPeriod.summaryTitle,
                    dateRangeText: viewModel.dateRangeText(for: snapshot.range),
                    totalTrackedText: DurationFormatting.abbreviated(snapshot.totalTrackedDuration),
                    dayCount: snapshot.range.dayCount
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
                        .chartLegend(position: .bottom, spacing: 12)
                        .accessibilityLabel("Category share chart")
                    } else {
                        ReportEmptyState(message: "No tracked time falls inside the selected range.")
                    }
                }

                ReportCard(title: "Total Time by Activity") {
                    if snapshot.totalTrackedDuration > 0 {
                        Chart(snapshot.summaries) { summary in
                            BarMark(
                                x: .value("Total", summary.totalDuration),
                                y: .value("Activity", summary.category.displayName)
                            )
                            .foregroundStyle(by: .value("Activity", summary.category.displayName))
                        }
                        .frame(height: 340)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine()
                                AxisTick()
                                if let seconds = value.as(Double.self) {
                                    AxisValueLabel(DurationFormatting.abbreviated(seconds))
                                }
                            }
                        }
                        .chartLegend(.hidden)
                        .accessibilityLabel("Total time by activity chart")
                    } else {
                        ReportEmptyState(message: "Add sessions to see total-time comparisons.")
                    }
                }

                ReportTableCard(snapshot: snapshot)
            }
            .padding()
        }
        .navigationTitle("Reports")
        .sheet(isPresented: $viewModel.isShowingCustomRangeSheet) {
            CustomRangeSheet(viewModel: viewModel)
        }
    }
}

private struct ReportOverviewCard: View {
    let title: String
    let dateRangeText: String
    let totalTrackedText: String
    let dayCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            Text(dateRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MetricBadge(title: "Tracked", value: totalTrackedText)
                MetricBadge(title: "Days", value: "\(dayCount)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(dateRangeText). Total tracked \(totalTrackedText) across \(dayCount) day\(dayCount == 1 ? "" : "s").")
    }
}

private struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

private struct ReportTableCard: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ReportCard(title: "Details") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Activity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Avg/day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Divider()
                    .gridCellColumns(4)

                ForEach(snapshot.summaries) { summary in
                    GridRow {
                        Label(summary.category.displayName, systemImage: summary.category.symbolName)
                            .font(.subheadline)

                        Text(DurationFormatting.abbreviated(summary.averagePerDay))
                            .font(.subheadline.monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(DurationFormatting.abbreviated(summary.totalDuration))
                            .font(.subheadline.monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(PercentageFormatting.wholePercent(summary.percentage))
                            .font(.subheadline.monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .trailing)
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

private enum ReportPeriod: String, CaseIterable, Identifiable {
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
        "\(DateFormatting.shortDateTime(range.start)) - \(DateFormatting.shortDateTime(range.end))"
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(SampleData.previewContainer)
}
