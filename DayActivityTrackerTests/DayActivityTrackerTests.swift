import XCTest
@testable import DayActivityTracker

final class DayActivityTrackerTests: XCTestCase {
    func testLearnCategoriesSupportSubActivities() {
        XCTAssertTrue(ActivityCategory.activeLearn.supportsSubActivities)
        XCTAssertTrue(ActivityCategory.passiveLearn.supportsSubActivities)
        XCTAssertFalse(ActivityCategory.work.supportsSubActivities)
    }
}
