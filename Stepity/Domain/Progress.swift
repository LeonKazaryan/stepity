import Foundation

/// Everything the screens show, worked out from the history and the journey in one go. Pure:
/// the same inputs always give the same picture, so it's easy to test.
struct ProgressSnapshot: Sendable {
    /// From the first day Health has: the prologue's numbers. Not part of the journey.
    let lifetime: ActivityTotals
    let lifetimeSince: Date?
    /// Since the morning of the install: the journey.
    let journey: ActivityTotals
    let today: ActivityTotals
    let thisWeek: ActivityTotals
    let weekDays: [ActivityDay]
    let goal: WeeklyGoal
    let ladder: HeightLadder.State
    /// The walker's kilometres along the route (the journey's distance, capped at the end).
    let routeKm: Double
    let streak: WeekStreak

    var goalFill: Double { goal.fill(km: thisWeek.distanceKm) }

    init(history: ActivityHistory, installDate: Date, journeyRoute: Journey, now: Date = .now, bodyMassKg: Double? = nil) {
        let calendar = history.calendar
        lifetime = history.totals(from: .distantPast, to: .distantFuture, bodyMassKg: bodyMassKg)
        lifetimeSince = history.firstActiveDay
        journey = history.totals(sinceDayOf: installDate, bodyMassKg: bodyMassKg)
        let todayStart = calendar.startOfDay(for: now)
        today = history.totals(from: todayStart, to: .distantFuture, bodyMassKg: bodyMassKg)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        thisWeek = week.map { history.totals(from: max($0.start, calendar.startOfDay(for: installDate)), to: $0.end, bodyMassKg: bodyMassKg) } ?? ActivityTotals()
        weekDays = history.week(containing: now)
        goal = WeeklyGoal.pick(usualWeekKm: history.averageWeeklyKm(before: installDate))
        ladder = HeightLadder.state(metres: journey.metresClimbed)
        routeKm = min(journey.distanceKm, journeyRoute.totalKm)
        streak = WeekStreak(history: history, installDate: installDate, goal: goal, now: now)
    }
}

/// Weeks in a row with the weekly goal closed. A missed day doesn't matter, a missed week
/// does. The line on the globe glows brighter with every week of it.
struct WeekStreak: Equatable, Sendable {
    /// Whole weeks in a row, up to last week, plus this one if it's already closed.
    let weeks: Int
    let thisWeekClosed: Bool

    init(weeks: Int, thisWeekClosed: Bool) {
        self.weeks = weeks
        self.thisWeekClosed = thisWeekClosed
    }

    init(history: ActivityHistory, installDate: Date, goal: WeeklyGoal, now: Date) {
        let calendar = history.calendar
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            self.init(weeks: 0, thisWeekClosed: false)
            return
        }
        let closedNow = history.totals(from: thisWeek.start, to: thisWeek.end).distanceKm >= goal.course.km
        var count = 0
        var start = thisWeek.start
        let first = calendar.startOfDay(for: installDate)
        // Only weeks since the install count: the streak is part of the journey.
        while let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: start), previous >= calendar.dateInterval(of: .weekOfYear, for: first)?.start ?? first {
            let km = history.totals(from: previous, to: start).distanceKm
            guard km >= goal.course.km else { break }
            count += 1
            start = previous
        }
        self.init(weeks: count + (closedNow ? 1 : 0), thisWeekClosed: closedNow)
    }

    /// 0 plain … 3 golden, for the trail's glow.
    var glow: Float {
        switch weeks {
        case 0: 0.6
        case 1...2: 1.2
        case 3...9: 2
        default: 3
        }
    }
}

/// What changed since the user last looked: the heart of the app. Played as a scene when it
/// opens after a walk.
struct SinceLastTime: Sendable {
    let fromKm: Double
    let toKm: Double
    let fromMetres: Double
    let toMetres: Double
    let steps: Int
    let stopsPassed: [JourneyStop]
    let summitsConquered: [Summit]
    let milestones: [DistanceMilestones.Milestone]
    let goalBefore: Double
    let goalAfter: Double
    let goalCourse: WeeklyGoal.Course
    let nextStop: JourneyStop?

    var addedKm: Double { toKm - fromKm }
    /// Worth a scene: at least a hundred metres, or something conquered.
    var isWorthShowing: Bool { addedKm >= 0.1 || !summitsConquered.isEmpty }
    /// Something big happened: a summit, a milestone or a city, not just a rest stop.
    var hasConquest: Bool {
        !summitsConquered.isEmpty || !milestones.isEmpty || stopsPassed.contains { $0.isMajor || $0.kind == .town }
    }

    init(seen: SeenProgress, now snapshot: ProgressSnapshot, journey: Journey) {
        fromKm = min(seen.km, snapshot.routeKm)
        toKm = snapshot.routeKm
        fromMetres = min(seen.metres, snapshot.journey.metresClimbed)
        toMetres = snapshot.journey.metresClimbed
        steps = max(0, snapshot.journey.steps - seen.steps)
        stopsPassed = journey.stops(passedFrom: fromKm, to: toKm)
        summitsConquered = HeightLadder.conquered(from: fromMetres, to: toMetres)
        milestones = DistanceMilestones.crossed(from: min(seen.km, snapshot.journey.distanceKm), to: snapshot.journey.distanceKm)
        let sameWeek = Calendar.current.isDate(seen.date, equalTo: .now, toGranularity: .weekOfYear)
        goalBefore = sameWeek ? snapshot.goal.fill(km: max(0, snapshot.thisWeek.distanceKm - (toKm - fromKm))) : 0
        goalAfter = snapshot.goalFill
        goalCourse = snapshot.goal.course
        nextStop = journey.nextStop(after: toKm)
    }
}

/// What the user saw last time the scene played, so the next one starts from there.
struct SeenProgress: Codable, Equatable, Sendable {
    var km: Double
    var metres: Double
    var steps: Int
    var date: Date
}
