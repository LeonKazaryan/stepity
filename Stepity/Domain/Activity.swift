import Foundation

/// One day of moving, as Apple Health sums it. Read-only: Stepity never writes to Health.
struct ActivityDay: Equatable, Sendable {
    /// Midnight that starts the day, in the user's calendar.
    let date: Date
    var steps: Int
    var distanceKm: Double
    /// Flights of stairs; one is about 3 m up.
    var floors: Int
    /// Active energy from Health, when something measured it (usually an Apple Watch).
    /// `nil` on an iPhone alone: `EnergyEstimate` fills in.
    var activeKcal: Double?
}

/// Sums over a stretch of days.
struct ActivityTotals: Equatable, Sendable {
    var steps = 0
    var distanceKm = 0.0
    var floors = 0
    var activeKcal = 0.0
    var days = 0

    /// Metres climbed: Health counts a floor for about 3 m up.
    var metresClimbed: Double { Double(floors) * ActivityTotals.metresPerFloor }

    static let metresPerFloor = 3.0

    static func + (lhs: ActivityTotals, rhs: ActivityTotals) -> ActivityTotals {
        ActivityTotals(
            steps: lhs.steps + rhs.steps,
            distanceKm: lhs.distanceKm + rhs.distanceKm,
            floors: lhs.floors + rhs.floors,
            activeKcal: lhs.activeKcal + rhs.activeKcal,
            days: lhs.days + rhs.days
        )
    }
}

/// The history Stepity works from: every day Health has, oldest first, with no gaps.
struct ActivityHistory: Equatable, Sendable {
    let days: [ActivityDay]
    let calendar: Calendar

    init(days: [ActivityDay], calendar: Calendar = .current) {
        self.days = days.sorted { $0.date < $1.date }
        self.calendar = calendar
    }

    /// The first day with any steps: the start of the prologue.
    var firstActiveDay: Date? { days.first { $0.steps > 0 }?.date }

    /// Everything, for the prologue.
    var lifetime: ActivityTotals { totals(from: .distantPast, to: .distantFuture) }

    /// Days whose midnight is in `start ..< end`, summed. Missing energy is estimated.
    func totals(from start: Date, to end: Date, bodyMassKg: Double? = nil) -> ActivityTotals {
        var sum = ActivityTotals()
        for day in days where day.date >= start && day.date < end {
            sum.steps += day.steps
            sum.distanceKm += day.distanceKm
            sum.floors += day.floors
            sum.activeKcal += day.activeKcal ?? EnergyEstimate.kcal(steps: day.steps, bodyMassKg: bodyMassKg)
            sum.days += 1
        }
        return sum
    }

    /// Since the start of `date`'s day: the journey counts from the morning of the install,
    /// so the first day is never empty.
    func totals(sinceDayOf date: Date, bodyMassKg: Double? = nil) -> ActivityTotals {
        totals(from: calendar.startOfDay(for: date), to: .distantFuture, bodyMassKg: bodyMassKg)
    }

    func day(containing date: Date) -> ActivityDay? {
        let start = calendar.startOfDay(for: date)
        return days.last { $0.date == start }
    }

    /// The seven days of the week holding `date`, Monday (or the calendar's first day) first.
    /// Days not in the history are zero.
    func week(containing date: Date) -> [ActivityDay] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return days.last { $0.date == start } ?? ActivityDay(date: start, steps: 0, distanceKm: 0, floors: 0, activeKcal: nil)
        }
    }

    /// Average kilometres per full week over the `weeks` weeks before `date`'s week. Weeks
    /// with nothing recorded don't count, so a phone that sat in a drawer doesn't lower it.
    func averageWeeklyKm(before date: Date, weeks: Int = 8) -> Double? {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        var totals: [Double] = []
        for back in 1...weeks {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek.start),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let km = self.totals(from: start, to: end).distanceKm
            if km > 0.5 { totals.append(km) }
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(0, +) / Double(totals.count)
    }
}

/// Active energy when Health has none: walking costs about 0.04 kcal a step for 70 kg,
/// more for heavier people. A rough figure, always shown with "≈".
enum EnergyEstimate {
    static let kcalPerStepAt70Kg = 0.04

    static func kcal(steps: Int, bodyMassKg: Double?) -> Double {
        Double(steps) * kcalPerStepAt70Kg * ((bodyMassKg ?? 70) / 70)
    }
}
