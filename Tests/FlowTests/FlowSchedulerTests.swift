import XCTest
@testable import Flow

@MainActor
final class FlowSchedulerTests: XCTestCase {
    func testExpiredPendingEntryIsMarkedAsFailed() {
        let timer = TimerViewModel()
        let now = Date()
        let expiredEntry = ScheduledTimerEntry(
            title: "Missed Session",
            startDate: now.addingTimeInterval(-3600),
            durationSeconds: 1200
        )

        let scheduler = FlowScheduler(
            timer: timer,
            entries: [expiredEntry],
            shouldMonitor: false,
            persistenceDisabled: true
        )

        scheduler.tick(now: now)

        guard let updated = scheduler.entries.first else {
            XCTFail("Expected scheduled entry to be present")
            return
        }

        XCTAssertEqual(updated.status, .failed)
        XCTAssertEqual(updated.note, "Missed scheduled window")
    }
}
