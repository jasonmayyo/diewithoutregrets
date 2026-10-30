import XCTest
@testable import StudyReliability

final class StudyCalendarTests: XCTestCase {
    private func calendar(firstWeekday: Int = 1, timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testWeekdayPreferenceMovesBothHeadingsAndDates() {
        let sunday = calendar()
        let monday = calendar(firstWeekday: 2)
        let october = date(2026, 10, 30, in: sunday)
        let sundayMonth = StudyCalendarMonth(containing: october, calendar: sunday)
        let mondayMonth = StudyCalendarMonth(containing: october, calendar: monday)
        XCTAssertEqual(sundayMonth.days.firstIndex(where: { $0 != nil }), 4)
        XCTAssertEqual(mondayMonth.days.firstIndex(where: { $0 != nil }), 3)
        XCTAssertEqual(sundayMonth.weekdaySymbols, ["S", "M", "T", "W", "T", "F", "S"])
        XCTAssertEqual(mondayMonth.weekdaySymbols, ["M", "T", "W", "T", "F", "S", "S"])
    }

    func testLeapDayAndSixWeekMonthAreNotDropped() {
        let cal = calendar()
        let leapMonth = StudyCalendarMonth(containing: date(2028, 2, 12, in: cal), calendar: cal)
        XCTAssertEqual(leapMonth.days.compactMap { $0 }.count, 29)
        XCTAssertEqual(cal.component(.day, from: leapMonth.days.compactMap { $0 }.last!), 29)
        let sixWeeks = StudyCalendarMonth(containing: date(2026, 5, 31, in: cal), calendar: cal)
        XCTAssertEqual(sixWeeks.days.count, 42)
        XCTAssertEqual(sixWeeks.days.compactMap { $0 }.count, 31)
        XCTAssertEqual(sixWeeks.days.last!, nil)
    }

    func testGridCoversEveryLocalDayAcrossDaylightSavingChanges() {
        let cal = calendar(timeZone: "America/New_York")
        for monthNumber in [3, 11] {
            let month = StudyCalendarMonth(containing: date(2026, monthNumber, 15, in: cal), calendar: cal)
            let dates = month.days.compactMap { $0 }
            let count = cal.range(of: .day, in: .month, for: month.start)!.count
            XCTAssertEqual(dates.map { cal.component(.day, from: $0) }, Array(1...count))
            XCTAssertEqual(Set(dates).count, count)
            XCTAssertTrue(dates.allSatisfy { cal.component(.hour, from: $0) == 0 })
            XCTAssertEqual(month.days.count % 7, 0)
        }
    }

    func testMonthNavigationFromMonthStartDoesNotSkipShortMonthsOrYearBoundary() {
        let cal = calendar()
        let january = StudyCalendarMonth(containing: date(2026, 1, 31, in: cal), calendar: cal)
        let february = cal.date(byAdding: .month, value: 1, to: january.start)!
        let december = cal.date(byAdding: .month, value: -1, to: january.start)!
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: february),
                       DateComponents(year: 2026, month: 2, day: 1))
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: december),
                       DateComponents(year: 2025, month: 12, day: 1))
    }
}
