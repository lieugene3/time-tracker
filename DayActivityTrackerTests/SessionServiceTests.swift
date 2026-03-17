import Foundation
import SwiftData
import XCTest
@testable import DayActivityTracker

@MainActor
final class SessionServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var dateProvider: TestDateProvider!
    private var service: SessionService!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: ActivitySession.self,
            SavedSubActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        dateProvider = TestDateProvider(now: Self.makeDate(hour: 9, minute: 0))
        service = SessionService(dateProvider: dateProvider)
    }

    override func tearDownWithError() throws {
        service = nil
        dateProvider = nil
        context = nil
        container = nil
    }

    func testStartFirstSessionCreatesActiveSession() throws {
        let session = try service.startSession(category: .work, in: context)

        XCTAssertEqual(session.category, .work)
        XCTAssertEqual(session.startAt, dateProvider.now)
        XCTAssertNil(session.endAt)
        XCTAssertEqual(try fetchSessions().count, 1)
        XCTAssertEqual(try service.currentActiveSession(in: context)?.id, session.id)
    }

    func testSelectingDifferentActivityEndsOldSessionAndStartsNewOne() throws {
        let firstSession = try service.startSession(category: .work, in: context)
        dateProvider.now = Self.makeDate(hour: 10, minute: 15)

        let secondSession = try service.selectActivity(category: .exercise, in: context)

        XCTAssertEqual(firstSession.endAt, dateProvider.now)
        XCTAssertEqual(secondSession.category, .exercise)
        XCTAssertEqual(secondSession.startAt, dateProvider.now)
        XCTAssertNil(secondSession.endAt)
        XCTAssertEqual(try fetchSessions().count, 2)
        XCTAssertEqual(try service.currentActiveSession(in: context)?.id, secondSession.id)
    }

    func testSelectingSameActiveActivityDoesNothing() throws {
        let activeSession = try service.startSession(
            category: .activeLearn,
            subActivityName: "SwiftUI",
            in: context
        )
        dateProvider.now = Self.makeDate(hour: 9, minute: 45)

        let reusedSession = try service.selectActivity(
            category: .activeLearn,
            subActivityName: "  swiftui  ",
            in: context
        )

        XCTAssertEqual(reusedSession.id, activeSession.id)
        XCTAssertNil(reusedSession.endAt)
        XCTAssertEqual(try fetchSessions().count, 1)
        XCTAssertEqual(try fetchSavedSubActivities().count, 1)
    }

    func testStopTrackingEndsCurrentSession() throws {
        let activeSession = try service.startSession(category: .social, in: context)
        dateProvider.now = Self.makeDate(hour: 11, minute: 5)

        let stoppedSession = try service.stopCurrentSession(in: context)

        XCTAssertEqual(stoppedSession.id, activeSession.id)
        XCTAssertEqual(stoppedSession.endAt, dateProvider.now)
        XCTAssertNil(try service.currentActiveSession(in: context))
    }

    func testStartSessionRejectsSecondActiveSession() throws {
        _ = try service.startSession(category: .work, in: context)
        dateProvider.now = Self.makeDate(hour: 9, minute: 30)

        XCTAssertThrowsError(try service.startSession(category: .exercise, in: context)) { error in
            XCTAssertEqual(error as? SessionServiceError, .activeSessionExists)
        }
    }

    func testCreateCompletedSessionRejectsOverlap() throws {
        _ = try service.createCompletedSession(
            category: .work,
            startAt: Self.makeDate(hour: 8, minute: 0),
            endAt: Self.makeDate(hour: 9, minute: 0),
            in: context
        )

        XCTAssertThrowsError(
            try service.createCompletedSession(
                category: .exercise,
                startAt: Self.makeDate(hour: 8, minute: 30),
                endAt: Self.makeDate(hour: 9, minute: 30),
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? SessionServiceError, .overlappingSession)
        }
    }

    func testUpdateSessionRejectsOverlap() throws {
        let firstSession = try service.createCompletedSession(
            category: .work,
            startAt: Self.makeDate(hour: 8, minute: 0),
            endAt: Self.makeDate(hour: 9, minute: 0),
            in: context
        )
        let secondSession = try service.createCompletedSession(
            category: .personal,
            startAt: Self.makeDate(hour: 9, minute: 30),
            endAt: Self.makeDate(hour: 10, minute: 15),
            in: context
        )

        XCTAssertNotEqual(firstSession.id, secondSession.id)

        XCTAssertThrowsError(
            try service.updateSession(
                secondSession,
                category: .personal,
                startAt: Self.makeDate(hour: 8, minute: 45),
                endAt: Self.makeDate(hour: 10, minute: 15),
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? SessionServiceError, .overlappingSession)
        }
    }

    func testSubActivitiesAreReusedCaseInsensitivelyAfterTrimming() throws {
        _ = try service.startSession(
            category: .activeLearn,
            subActivityName: "  SwiftUI  ",
            in: context
        )
        dateProvider.now = Self.makeDate(hour: 9, minute: 30)
        _ = try service.stopCurrentSession(in: context)
        dateProvider.now = Self.makeDate(hour: 10, minute: 0)

        let session = try service.startSession(
            category: .activeLearn,
            subActivityName: "swiftui",
            in: context
        )

        let savedSubActivities = try fetchSavedSubActivities()
        XCTAssertEqual(savedSubActivities.count, 1)
        XCTAssertEqual(savedSubActivities.first?.name, "SwiftUI")
        XCTAssertEqual(savedSubActivities.first?.lastUsedAt, dateProvider.now)
        XCTAssertEqual(session.subActivityName, "SwiftUI")
    }

    func testSubActivitiesRemainScopedToTheirParentCategory() throws {
        _ = try service.startSession(
            category: .activeLearn,
            subActivityName: "Reading",
            in: context
        )
        dateProvider.now = Self.makeDate(hour: 9, minute: 20)
        _ = try service.stopCurrentSession(in: context)
        dateProvider.now = Self.makeDate(hour: 10, minute: 0)

        _ = try service.startSession(
            category: .passiveLearn,
            subActivityName: "Reading",
            in: context
        )

        let savedSubActivities = try fetchSavedSubActivities()
        XCTAssertEqual(savedSubActivities.count, 2)
        XCTAssertEqual(
            Set(savedSubActivities.map(\.parentCategory)),
            Set([.activeLearn, .passiveLearn])
        )
    }

    func testCanClearEndDateOnlyForMostRecentSession() throws {
        let firstSession = try service.createCompletedSession(
            category: .work,
            startAt: Self.makeDate(hour: 8, minute: 0),
            endAt: Self.makeDate(hour: 9, minute: 0),
            in: context
        )
        let secondSession = try service.createCompletedSession(
            category: .exercise,
            startAt: Self.makeDate(hour: 9, minute: 15),
            endAt: Self.makeDate(hour: 10, minute: 0),
            in: context
        )

        XCTAssertFalse(try service.canClearEndDate(for: firstSession, in: context))
        XCTAssertTrue(try service.canClearEndDate(for: secondSession, in: context))
    }

    func testHistoryTimelineSplitsCrossMidnightSessionIntoDaySections() throws {
        let session = try service.createCompletedSession(
            category: .work,
            startAt: Self.makeDate(day: 16, hour: 23, minute: 0),
            endAt: Self.makeDate(day: 17, hour: 1, minute: 0),
            in: context
        )

        let sections = HistoryTimelineBuilder(calendar: Self.testCalendar).makeSections(
            from: [session],
            now: Self.makeDate(day: 17, hour: 1, minute: 0)
        )

        XCTAssertEqual(sections.map(\.dayStart), [Self.startOfDay(day: 17), Self.startOfDay(day: 16)])
        XCTAssertEqual(sections[0].segments.count, 1)
        XCTAssertEqual(sections[1].segments.count, 1)

        let newerDaySegment = sections[0].segments[0]
        XCTAssertEqual(newerDaySegment.sourceSession.id, session.id)
        XCTAssertEqual(newerDaySegment.startAt, Self.makeDate(day: 17, hour: 0, minute: 0))
        XCTAssertEqual(newerDaySegment.endAt, Self.makeDate(day: 17, hour: 1, minute: 0))

        let olderDaySegment = sections[1].segments[0]
        XCTAssertEqual(olderDaySegment.sourceSession.id, session.id)
        XCTAssertEqual(olderDaySegment.startAt, Self.makeDate(day: 16, hour: 23, minute: 0))
        XCTAssertEqual(olderDaySegment.endAt, Self.makeDate(day: 17, hour: 0, minute: 0))
    }

    func testHistoryTimelineUsesNowForActiveSessionSegmentEnd() throws {
        let activeSession = try service.startSession(category: .sleep, in: context)
        let now = Self.makeDate(hour: 11, minute: 30)

        let sections = HistoryTimelineBuilder(calendar: Self.testCalendar).makeSections(
            from: [activeSession],
            now: now
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].segments.count, 1)
        XCTAssertTrue(sections[0].segments[0].showsNowAsEnd)
        XCTAssertEqual(sections[0].segments[0].endAt, now)
    }

    private func fetchSessions() throws -> [ActivitySession] {
        try context.fetch(FetchDescriptor<ActivitySession>(sortBy: [SortDescriptor(\.startAt, order: .forward)]))
    }

    private func fetchSavedSubActivities() throws -> [SavedSubActivity] {
        try context.fetch(FetchDescriptor<SavedSubActivity>())
    }

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private static func makeDate(day: Int = 17, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = testCalendar.timeZone
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }

    private static func startOfDay(day: Int) -> Date {
        testCalendar.startOfDay(for: makeDate(day: day, hour: 12, minute: 0))
    }
}

private final class TestDateProvider: DateProvider {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
