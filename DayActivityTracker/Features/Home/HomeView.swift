import Foundation
import Observation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]
    @Query(sort: \SavedSubActivity.lastUsedAt, order: .reverse) private var savedSubActivities: [SavedSubActivity]
    @State private var viewModel = HomeViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let activeSession = viewModel.activeSession(from: sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Current Activity")
                    .font(.title2.weight(.semibold))

                if let activeSession {
                    CurrentActivityCard(session: activeSession) {
                        viewModel.stopTracking(in: modelContext)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No current activity")
                            .font(.headline)

                        Text("Choose what you're doing now.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No current activity. Choose what you're doing now.")
                }

                Text("Start or Switch")
                    .font(.title3.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ActivityCategory.allCases) { category in
                        Button {
                            viewModel.handleCategoryTap(category, in: modelContext)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: category.symbolName)
                                    .font(.title2)
                                Text(category.displayName)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                Text(category.supportsSubActivities ? "Choose or enter a sub-activity" : "Start immediately")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(category.displayName)")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .sheet(item: $viewModel.pickerCategory) { category in
            ActivityPickerSheet(
                category: category,
                savedSubActivities: savedSubActivities.filter {
                    $0.parentCategory == category && $0.isArchived == false
                },
                viewModel: viewModel
            )
        }
        .alert("Unable to Update Activity", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(SampleData.previewContainer)
}

@MainActor
@Observable
final class HomeViewModel {
    var pickerCategory: ActivityCategory?
    var subActivityDraft = ""
    var errorMessage: String?
    var isShowingError = false

    private let sessionService: SessionService

    init(sessionService: SessionService? = nil) {
        self.sessionService = sessionService ?? SessionService()
    }

    func activeSession(from sessions: [ActivitySession]) -> ActivitySession? {
        sessions.first(where: \.isActive)
    }

    func handleCategoryTap(_ category: ActivityCategory, in context: ModelContext) {
        if category.supportsSubActivities {
            pickerCategory = category
            subActivityDraft = ""
            return
        }

        startActivity(category: category, subActivityName: nil, in: context)
    }

    func startSavedSubActivity(_ savedSubActivity: SavedSubActivity, category: ActivityCategory, in context: ModelContext) {
        startActivity(category: category, subActivityName: savedSubActivity.name, in: context)
    }

    func startCustomSubActivity(for category: ActivityCategory, in context: ModelContext) {
        let trimmedName = subActivityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            presentError(message: "Sub-activity cannot be blank.")
            return
        }

        startActivity(category: category, subActivityName: trimmedName, in: context)
    }

    func continueWithoutSubActivity(for category: ActivityCategory, in context: ModelContext) {
        startActivity(category: category, subActivityName: nil, in: context)
    }

    func stopTracking(in context: ModelContext) {
        perform {
            try sessionService.stopCurrentSession(in: context)
        }
    }

    func dismissPicker() {
        pickerCategory = nil
        subActivityDraft = ""
    }

    func dismissError() {
        isShowingError = false
        errorMessage = nil
    }

    private func startActivity(category: ActivityCategory, subActivityName: String?, in context: ModelContext) {
        perform {
            try sessionService.selectActivity(
                category: category,
                subActivityName: subActivityName,
                in: context
            )
            dismissPicker()
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch let error as LocalizedError {
            presentError(message: error.errorDescription ?? "Something went wrong.")
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    private func presentError(message: String) {
        errorMessage = message
        isShowingError = true
    }
}

struct ActivityPickerSheet: View {
    @Environment(\.modelContext) private var modelContext

    let category: ActivityCategory
    let savedSubActivities: [SavedSubActivity]
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved") {
                    if savedSubActivities.isEmpty {
                        Text("No saved sub-activities yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedSubActivities) { savedSubActivity in
                            Button {
                                viewModel.startSavedSubActivity(
                                    savedSubActivity,
                                    category: category,
                                    in: modelContext
                                )
                            } label: {
                                HStack {
                                    Text(savedSubActivity.name)
                                    Spacer()
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Use saved sub-activity \(savedSubActivity.name)")
                        }
                    }
                }

                Section("New") {
                    TextField("New sub-activity", text: $viewModel.subActivityDraft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .accessibilityLabel("New sub-activity")
                        .onSubmit {
                            viewModel.startCustomSubActivity(for: category, in: modelContext)
                        }

                    Button("Save and Start") {
                        viewModel.startCustomSubActivity(for: category, in: modelContext)
                    }
                    .accessibilityLabel("Save and start \(category.displayName) sub-activity")
                }

                Section {
                    Button("Continue without sub-activity") {
                        viewModel.continueWithoutSubActivity(for: category, in: modelContext)
                    }
                    .accessibilityLabel("Continue without sub-activity")
                }
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissPicker()
                    }
                }
            }
        }
    }
}

struct CurrentActivityCard: View {
    let session: ActivitySession
    let onStop: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.category.displayName, systemImage: session.category.symbolName)
                            .font(.title3.weight(.semibold))

                        if let subActivityName = session.subActivityName {
                            Text(subActivityName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        Text("Since \(DateFormatting.shortTime(session.startAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DurationFormatting.abbreviated(session.duration(now: timeline.date)))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(session.category.displayName), \(session.subActivityName ?? "No sub-activity"), since \(DateFormatting.shortTime(session.startAt)), duration \(DurationFormatting.abbreviated(session.duration(now: timeline.date)))."
                )

                Button(role: .destructive, action: onStop) {
                    Label("Stop Tracking", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Stop tracking")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
