import Foundation

struct EffectiveFocusCalculator {
    static func baselineSeconds(
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let twelveHours: TimeInterval = 12 * 3600
        let day: TimeInterval = 24 * 3600

        guard end > start else { return 0 }

        let startOfStartDay = calendar.startOfDay(for: start)
        let startOfEndDay = calendar.startOfDay(for: end)

        if startOfStartDay == startOfEndDay {
            return min(twelveHours, end.timeIntervalSince(start))
        }

        let startDayEnd = calendar.date(byAdding: .day, value: 1, to: startOfStartDay) ?? startOfStartDay.addingTimeInterval(day)
        let startContribution = min(twelveHours, max(0, startDayEnd.timeIntervalSince(start)))
        let endContribution = min(twelveHours, max(0, end.timeIntervalSince(startOfEndDay)))

        let dayDifference = calendar.dateComponents([.day], from: startOfStartDay, to: startOfEndDay).day ?? 0
        let middleDays = max(0, dayDifference - 1)
        let middleContribution = Double(middleDays) * twelveHours

        return startContribution + endContribution + middleContribution
    }
}
