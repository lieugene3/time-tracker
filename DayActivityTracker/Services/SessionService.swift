import Foundation
import SwiftData

enum SessionServiceError: LocalizedError, Equatable {
    case activeSessionExists
    case cannotClearEndDate
    case invalidDateRange
    case noActiveSession
    case overlappingSession

    var errorDescription: String? {
        switch self {
        case .activeSessionExists:
            "Only one active session can exist at a time."
        case .cannotClearEndDate:
            "Only the most recent session can be made active when no other active session exists."
        case .invalidDateRange:
            "End time must be later than start time."
        case .noActiveSession:
            "There is no active session to stop."
        case .overlappingSession:
            "Sessions cannot overlap."
        }
    }
}

@MainActor
final class SessionService {
    private let dateProvider: any DateProvider

    init(dateProvider: any DateProvider = SystemDateProvider()) {
        self.dateProvider = dateProvider
    }

    func currentActiveSession(in context: ModelContext) throws -> ActivitySession? {
        let activeSessions = try allSessions(in: context).filter(\.isActive)
        guard activeSessions.count <= 1 else {
            throw SessionServiceError.activeSessionExists
        }

        return activeSessions.first
    }

    @discardableResult
    func startSession(
        category: ActivityCategory,
        subActivityName: String? = nil,
        in context: ModelContext
    ) throws -> ActivitySession {
        guard try currentActiveSession(in: context) == nil else {
            throw SessionServiceError.activeSessionExists
        }

        let now = dateProvider.now
        try validateNoSessionContains(moment: now, excluding: nil, in: context)

        let preparedSubActivityName = try persistedSubActivityName(
            from: subActivityName,
            for: category,
            in: context
        )

        let session = ActivitySession(
            category: category,
            subActivityName: preparedSubActivityName,
            startAt: now,
            createdAt: now,
            updatedAt: now
        )

        context.insert(session)
        try context.save()
        return session
    }

    @discardableResult
    func selectActivity(
        category: ActivityCategory,
        subActivityName: String? = nil,
        in context: ModelContext
    ) throws -> ActivitySession {
        let normalizedRequestedSubActivity = normalizedSubActivityName(
            from: subActivityName,
            for: category
        )

        if let activeSession = try currentActiveSession(in: context) {
            let normalizedActiveSubActivity = normalizedSubActivityName(
                from: activeSession.subActivityName,
                for: activeSession.category
            )

            if activeSession.category == category,
               comparableSubActivityName(for: normalizedActiveSubActivity) == comparableSubActivityName(for: normalizedRequestedSubActivity) {
                return activeSession
            }

            let now = dateProvider.now
            activeSession.endAt = now
            activeSession.updatedAt = now
        }

        let now = dateProvider.now
        try validateNoSessionContains(moment: now, excluding: nil, in: context)

        let preparedSubActivityName = try persistedSubActivityName(
            from: normalizedRequestedSubActivity,
            for: category,
            in: context
        )

        let newSession = ActivitySession(
            category: category,
            subActivityName: preparedSubActivityName,
            startAt: now,
            createdAt: now,
            updatedAt: now
        )

        context.insert(newSession)
        try context.save()
        return newSession
    }

    @discardableResult
    func stopCurrentSession(in context: ModelContext) throws -> ActivitySession {
        guard let activeSession = try currentActiveSession(in: context) else {
            throw SessionServiceError.noActiveSession
        }

        let now = dateProvider.now
        activeSession.endAt = now
        activeSession.updatedAt = now
        try context.save()
        return activeSession
    }

    @discardableResult
    func createCompletedSession(
        category: ActivityCategory,
        subActivityName: String? = nil,
        startAt: Date,
        endAt: Date,
        in context: ModelContext
    ) throws -> ActivitySession {
        try validateNoOverlap(startAt: startAt, endAt: endAt, excluding: nil, in: context)

        let now = dateProvider.now
        let preparedSubActivityName = try persistedSubActivityName(
            from: subActivityName,
            for: category,
            in: context
        )

        let session = ActivitySession(
            category: category,
            subActivityName: preparedSubActivityName,
            startAt: startAt,
            endAt: endAt,
            createdAt: now,
            updatedAt: now
        )

        context.insert(session)
        try context.save()
        return session
    }

    @discardableResult
    func updateSession(
        _ session: ActivitySession,
        category: ActivityCategory,
        subActivityName: String? = nil,
        startAt: Date,
        endAt: Date?,
        in context: ModelContext
    ) throws -> ActivitySession {
        if let endAt {
            try validateNoOverlap(startAt: startAt, endAt: endAt, excluding: session.id, in: context)
        } else {
            guard try isMostRecentSession(session, in: context) else {
                throw SessionServiceError.cannotClearEndDate
            }

            let otherActiveSession = try allSessions(in: context).first { $0.id != session.id && $0.isActive }
            guard otherActiveSession == nil else {
                throw SessionServiceError.activeSessionExists
            }

            try validateNoOverlap(startAt: startAt, endAt: nil, excluding: session.id, in: context)
        }

        session.category = category
        session.subActivityName = try persistedSubActivityName(from: subActivityName, for: category, in: context)
        session.startAt = startAt
        session.endAt = endAt
        session.updatedAt = dateProvider.now

        try context.save()
        return session
    }

    func deleteSession(_ session: ActivitySession, in context: ModelContext) throws {
        context.delete(session)
        try context.save()
    }

    func savedSubActivities(
        for category: ActivityCategory,
        in context: ModelContext
    ) throws -> [SavedSubActivity] {
        let parentCategoryRaw = category.rawValue
        let descriptor = FetchDescriptor<SavedSubActivity>(
            predicate: #Predicate<SavedSubActivity> {
                $0.parentCategoryRaw == parentCategoryRaw && $0.isArchived == false
            },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func allSessions(in context: ModelContext) throws -> [ActivitySession] {
        let descriptor = FetchDescriptor<ActivitySession>(
            sortBy: [SortDescriptor(\.startAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    private func isMostRecentSession(_ session: ActivitySession, in context: ModelContext) throws -> Bool {
        let now = dateProvider.now
        let latestSession = try allSessions(in: context).max {
            let leftEnd = $0.effectiveEndDate(now: now)
            let rightEnd = $1.effectiveEndDate(now: now)

            if leftEnd == rightEnd {
                return $0.startAt < $1.startAt
            }

            return leftEnd < rightEnd
        }

        return latestSession?.id == session.id
    }

    private func validateNoOverlap(
        startAt: Date,
        endAt: Date?,
        excluding excludedSessionID: UUID?,
        in context: ModelContext
    ) throws {
        let effectiveEndAt = endAt ?? dateProvider.now
        guard effectiveEndAt > startAt else {
            throw SessionServiceError.invalidDateRange
        }

        for session in try allSessions(in: context) where session.id != excludedSessionID {
            let otherEndAt = session.effectiveEndDate(now: dateProvider.now)
            if session.startAt < effectiveEndAt && startAt < otherEndAt {
                throw SessionServiceError.overlappingSession
            }
        }
    }

    private func validateNoSessionContains(
        moment: Date,
        excluding excludedSessionID: UUID?,
        in context: ModelContext
    ) throws {
        for session in try allSessions(in: context) where session.id != excludedSessionID {
            let otherEndAt = session.effectiveEndDate(now: dateProvider.now)
            if session.startAt <= moment && moment < otherEndAt {
                throw SessionServiceError.overlappingSession
            }
        }
    }

    private func persistedSubActivityName(
        from rawName: String?,
        for category: ActivityCategory,
        in context: ModelContext
    ) throws -> String? {
        guard let normalizedName = normalizedSubActivityName(from: rawName, for: category) else {
            return nil
        }

        let comparableName = comparableSubActivityName(for: normalizedName)
        if let existingSubActivity = try savedSubActivities(for: category, in: context).first(where: {
            comparableSubActivityName(for: $0.name) == comparableName
        }) {
            existingSubActivity.lastUsedAt = dateProvider.now
            existingSubActivity.isArchived = false
            return existingSubActivity.name
        }

        let subActivity = SavedSubActivity(
            parentCategory: category,
            name: normalizedName,
            createdAt: dateProvider.now,
            lastUsedAt: dateProvider.now
        )
        context.insert(subActivity)
        return normalizedName
    }

    private func normalizedSubActivityName(from rawName: String?, for category: ActivityCategory) -> String? {
        guard category.supportsSubActivities else {
            return nil
        }

        guard let rawName else {
            return nil
        }

        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }

    private func comparableSubActivityName(for rawName: String?) -> String? {
        guard let rawName else {
            return nil
        }

        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return nil
        }

        return trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
