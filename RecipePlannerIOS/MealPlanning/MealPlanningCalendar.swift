import Foundation

enum MealPlannerCalendarViewMode: String, CaseIterable, Identifiable, Hashable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

enum ShoppingListPeriod: String, CaseIterable, Identifiable, Hashable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

struct MealPlannerCalendarSelection: Equatable {
    private(set) var selectedDate: Date
    private(set) var viewMode: MealPlannerCalendarViewMode

    init(
        selectedDate: Date = Date(),
        viewMode: MealPlannerCalendarViewMode = .month,
        calendar: Calendar = .current
    ) {
        self.selectedDate = calendar.startOfDay(for: selectedDate)
        self.viewMode = viewMode
    }

    mutating func selectViewMode(_ mode: MealPlannerCalendarViewMode) {
        // Changing presentation never changes the anchored local calendar date.
        viewMode = mode
    }

    mutating func selectDate(_ date: Date, calendar: Calendar = .current) {
        selectedDate = calendar.startOfDay(for: date)
    }

    mutating func navigate(by amount: Int, calendar: Calendar = .current) {
        if viewMode == .month,
           let updated = MealPlanningCalendar.monthDate(byAdding: amount, to: selectedDate, calendar: calendar) {
            selectedDate = calendar.startOfDay(for: updated)
            return
        }

        let component: Calendar.Component = switch viewMode {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        if let updated = calendar.date(byAdding: component, value: amount, to: selectedDate) {
            selectedDate = calendar.startOfDay(for: updated)
        }
    }

    mutating func returnToToday(_ today: Date = Date(), calendar: Calendar = .current) {
        selectedDate = calendar.startOfDay(for: today)
    }
}

enum MealPlannerCalendarMotion {
    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : 0.22
    }
}

struct MealPlanningDateRange: Equatable {
    /// Inclusive local start of the first calendar day.
    let startDate: Date
    /// Exclusive local start of the day after the range.
    let endDateExclusive: Date

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= startDate && day < endDateExclusive
    }

    func lastDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: endDateExclusive) ?? startDate
    }
}

enum MealPlanningCalendar {
    static func configured(
        locale: Locale = .current,
        firstWeekday: Int? = nil,
        base: Calendar = .current
    ) -> Calendar {
        var calendar = base
        calendar.locale = locale
        if let firstWeekday, (1...7).contains(firstWeekday) {
            calendar.firstWeekday = firstWeekday
        }
        return calendar
    }

    static func dateRange(
        for period: ShoppingListPeriod,
        containing anchor: Date,
        calendar: Calendar = .current
    ) -> MealPlanningDateRange? {
        let day = calendar.startOfDay(for: anchor)
        let start: Date
        let component: Calendar.Component

        switch period {
        case .day:
            start = day
            component = .day
        case .week:
            let weekday = calendar.component(.weekday, from: day)
            let offset = (weekday - calendar.firstWeekday + 7) % 7
            guard let firstDay = calendar.date(byAdding: .day, value: -offset, to: day) else { return nil }
            start = calendar.startOfDay(for: firstDay)
            component = .weekOfYear
        case .month:
            let components = calendar.dateComponents([.era, .year, .month], from: day)
            guard let firstDay = calendar.date(from: components) else { return nil }
            start = calendar.startOfDay(for: firstDay)
            component = .month
        }

        guard let end = calendar.date(byAdding: component, value: 1, to: start), end > start else { return nil }
        return MealPlanningDateRange(startDate: start, endDateExclusive: end)
    }

    static func dates(in range: MealPlanningDateRange, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        var date = range.startDate
        while date < range.endDateExclusive {
            dates.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            date = next
        }
        return dates
    }

    static func entries(
        _ entries: [MealPlanEntry],
        in range: MealPlanningDateRange,
        calendar: Calendar = .current
    ) -> [MealPlanEntry] {
        entries.filter { range.contains($0.date, calendar: calendar) }
    }

    static func monthDate(byAdding offset: Int, to date: Date, calendar: Calendar = .current) -> Date? {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard let monthStart = calendar.date(from: DateComponents(era: components.era, year: components.year, month: components.month)),
              let targetMonth = calendar.date(byAdding: .month, value: offset, to: monthStart),
              let dayRange = calendar.range(of: .day, in: .month, for: targetMonth),
              let day = components.day else { return nil }
        return calendar.date(byAdding: .day, value: min(day, dayRange.count) - 1, to: targetMonth)
    }
}
