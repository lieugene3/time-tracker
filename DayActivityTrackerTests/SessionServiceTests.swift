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

    private func fetchSessions() throws -> [ActivitySession] {
        try context.fetch(FetchDescriptor<ActivitySession>(sortBy: [SortDescriptor(\.startAt, order: .forward)]))
    }

    private func fetchSavedSubActivities() throws -> [SavedSubActivity] {
        try context.fetch(FetchDescriptor<SavedSubActivity>())
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/Toronto")
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}

private final class TestDateProvider: DateProvider {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
