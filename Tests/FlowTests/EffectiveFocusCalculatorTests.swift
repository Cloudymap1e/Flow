import XCTest
@testable import Flow

final class EffectiveFocusCalculatorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testEffectiveBaseForLateStartMatchesThirtyNineHours() {
        let start = makeDate(day: 17, hour: 17) // 5 PM start leaves 7 hours in day 17
        let end = makeDate(day: 20, hour: 8)
        let hours = EffectiveFocusCalculator.baselineSeconds(from: start, to: end, calendar: calendar) / 3600
        XCTAssertEqual(hours, 39, accuracy: 0.0001)
    }

    func testEffectiveBaseForMorningStartMatchesFortyFourHours() {
        let start = makeDate(day: 17, hour: 9)
        let end = makeDate(day: 20, hour: 8)
        let hours = EffectiveFocusCalculator.baselineSeconds(from: start, to: end, calendar: calendar) / 3600
        XCTAssertEqual(hours, 44, accuracy: 0.0001)
    }

    private func makeDate(day: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
