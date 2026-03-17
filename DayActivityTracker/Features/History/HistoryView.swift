import Foundation
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]
    @State private var destination: HistorySheetDestination?

    private let timelineBuilder = HistoryTimelineBuilder()

    var body: some View {
        List {
            if historySections.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "clock.badge.plus",
                    description: Text("Add a backfilled session to start building your history.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(historySections) { section in
                    Section(DateFormatting.dayHeader(section.dayStart)) {
                        ForEach(section.segments) { segment in
                            Button {
                                destination = .edit(sessionID: segment.sourceSession.id)
                            } label: {
                                HistorySessionRow(segment: segment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    destination = .create
                } label: {
                    Label("Add Session", systemImage: "plus")
                }
                .accessibilityLabel("Add backfilled session")
            }
        }
        .sheet(item: $destination) { destination in
            switch destination {
            case .create:
                HistoryEditorSheet(mode: .create)
            case .edit(let sessionID):
                if let session = sessions.first(where: { $0.id == sessionID }) {
                    HistoryEditorSheet(mode: .edit(session))
                } else {
                    ContentUnavailableView(
                        "Session Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected session no longer exists.")
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }

    private var historySections: [HistoryDaySection] {
        timelineBuilder.makeSections(from: sessions, now: Date())
    }
}

private struct HistorySessionRow: View {
    let segment: HistorySessionSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: segment.sourceSession.category.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(segment.sourceSession.category.displayName)
                    .font(.headline)

                if let subActivityName = segment.sourceSession.subActivityName {
                    Text(subActivityName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(DurationFormatting.abbreviated(segment.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(segment.sourceSession.category.displayName), \(segment.sourceSession.subActivityName ?? "No sub-activity"), \(timeRangeAccessibilityText), duration \(DurationFormatting.abbreviated(segment.duration))."
        )
    }

    private var timeRangeText: String {
        "\(DateFormatting.shortTime(segment.startAt)) - \(segment.showsNowAsEnd ? "Now" : DateFormatting.shortTime(segment.endAt))"
    }

    private var timeRangeAccessibilityText: String {
        "from \(DateFormatting.shortTime(segment.startAt)) to \(segment.showsNowAsEnd ? "Now" : DateFormatting.shortTime(segment.endAt))"
    }
}

@MainActor
private struct HistoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSubActivity.lastUsedAt, order: .reverse) private var savedSubActivities: [SavedSubActivity]

    let mode: HistoryEditorMode

    @State private var draft: SessionEditorDraft
    @State private var errorMessage: String?
    @State private var isShowingError = false

    init(mode: HistoryEditorMode) {
        self.mode = mode
        _draft = State(initialValue: SessionEditorDraft(mode: mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Text(category.displayName)
                                .tag(category)
                        }
                    }
                    .accessibilityLabel("Activity category")

                    if draft.category.supportsSubActivities {
                        TextField("Sub-activity", text: $draft.subActivityName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Sub-activity")

                        if filteredSavedSubActivities.isEmpty == false {
                            ForEach(filteredSavedSubActivities) { savedSubActivity in
                                Button(savedSubActivity.name) {
                                    draft.subActivityName = savedSubActivity.name
                                }
                                .accessibilityLabel("Use saved sub-activity \(savedSubActivity.name)")
                            }
                        }
                    }
                }

                Section("Timing") {
                    DatePicker(
                        "Start",
                        selection: $draft.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Start date and time")

                    if case .edit = mode {
                        Toggle("Keep session active", isOn: $draft.keepsSessionActive)
                            .disabled(canKeepSessionActive == false)
                            .accessibilityLabel("Keep session active")

                        if canKeepSessionActive == false && draft.keepsSessionActive == false {
                            Text("Only the most recent session can be reopened when no other active session exists.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showsEndDatePicker {
                        DatePicker(
                            "End",
                            selection: $draft.endAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityLabel("End date and time")
                    }
                }

                if case .edit = mode {
                    Section {
                        Button("Delete Session", role: .destructive) {
                            deleteSession()
                        }
                        .accessibilityLabel("Delete session")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.confirmationTitle) {
                        saveSession()
                    }
                }
            }
            .alert("Unable to Update Session", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {
                    isShowingError = false
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .onChange(of: draft.category) { _, newCategory in
                if newCategory.supportsSubActivities == false {
                    draft.subActivityName = ""
                }
            }
            .onChange(of: draft.keepsSessionActive) { _, keepsSessionActive in
                guard keepsSessionActive == false, draft.endAt <= draft.startAt else {
                    return
                }

                draft.endAt = max(Date(), draft.startAt.addingTimeInterval(60))
            }
        }
    }

    private var filteredSavedSubActivities: [SavedSubActivity] {
        savedSubActivities.filter {
            $0.parentCategory == draft.category && $0.isArchived == false
        }
    }

    private var showsEndDatePicker: Bool {
        switch mode {
        case .create:
            true
        case .edit:
            draft.keepsSessionActive == false
        }
    }

    private var canKeepSessionActive: Bool {
        switch mode {
        case .create:
            false
        case .edit(let session):
            if session.isActive {
                return true
            }

            return (try? SessionService().canClearEndDate(for: session, in: modelContext)) ?? false
        }
    }

    private func deleteSession() {
        guard case let .edit(session) = mode else {
            return
        }

        do {
            try SessionService().deleteSession(session, in: modelContext)
            dismiss()
        } catch {
            present(error)
        }
    }

    private func saveSession() {
        do {
            let sessionService = SessionService()
            let subActivityName = draft.preparedSubActivityName

            switch mode {
            case .create:
                _ = try sessionService.createCompletedSession(
                    category: draft.category,
                    subActivityName: subActivityName,
                    startAt: draft.startAt,
                    endAt: draft.endAt,
                    in: modelContext
                )
            case .edit(let session):
                _ = try sessionService.updateSession(
                    session,
                    category: draft.category,
                    subActivityName: subActivityName,
                    startAt: draft.startAt,
                    endAt: draft.keepsSessionActive ? nil : draft.endAt,
                    in: modelContext
                )
            }

            dismiss()
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        if let localizedError = error as? LocalizedError {
            errorMessage = localizedError.errorDescription ?? "Something went wrong."
        } else {
            errorMessage = error.localizedDescription
        }

        isShowingError = true
    }
}

private enum HistorySheetDestination: Identifiable {
    case create
    case edit(sessionID: UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let sessionID):
            "edit-\(sessionID.uuidString)"
        }
    }
}

private enum HistoryEditorMode {
    case create
    case edit(ActivitySession)

    var title: String {
        switch self {
        case .create:
            "Add Session"
        case .edit:
            "Edit Session"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .create:
            "Add"
        case .edit:
            "Save"
        }
    }
}

private struct SessionEditorDraft {
    var category: ActivityCategory
    var subActivityName: String
    var startAt: Date
    var endAt: Date
    var keepsSessionActive: Bool

    init(mode: HistoryEditorMode, now: Date = .now) {
        switch mode {
        case .create:
            category = .work
            subActivityName = ""
            startAt = now.addingTimeInterval(-3_600)
            endAt = now
            keepsSessionActive = false
        case .edit(let session):
            category = session.category
            subActivityName = session.subActivityName ?? ""
            startAt = session.startAt
            endAt = session.endAt ?? now
            keepsSessionActive = session.isActive
        }
    }

    var preparedSubActivityName: String? {
        guard category.supportsSubActivities else {
            return nil
        }

        let trimmedName = subActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(SampleData.previewContainer)
}
