import Foundation
import Testing
@testable import Stepity

@Suite("Trail path")
struct TrailPathTests {
    private let path = TrailPath(
        coordinates: [GeoCoordinate(latitude: 0, longitude: 0), GeoCoordinate(latitude: 0, longitude: 10), GeoCoordinate(latitude: 10, longitude: 10)],
        kilometres: [0, 1_000, 2_000]
    )

    @Test func endsAreClamped() {
        #expect(path.coordinate(atKm: -5) == path.coordinates[0])
        #expect(path.coordinate(atKm: 99_999) == path.coordinates[2])
    }

    @Test func halfwayIsOnTheGreatCircle() {
        let middle = path.coordinate(atKm: 500)
        #expect(abs(middle.latitude) < 1e-6)
        #expect(abs(middle.longitude - 5) < 1e-6)
    }

    @Test func meshFollowsTheCurve() {
        let mesh = TrailGeometry.mesh(path, stepKm: 100)
        // Every 100 km or closer, two triangles per piece, ends flagged.
        #expect(mesh.points.count > 20)
        #expect(mesh.indices.count == (mesh.points.count - 1) * 6)
        #expect(mesh.points.first?.params.y == 1)
        #expect(mesh.points.last?.params.y == 2)
        // Kilometres rise along the ribbon.
        let kms = mesh.points.map(\.position.w)
        #expect(kms == kms.sorted())
    }

    @Test func distanceAlmatyParis() {
        let km = TrailGeometry.distanceKm(GeoCoordinate(latitude: 43.24, longitude: 76.95), GeoCoordinate(latitude: 48.86, longitude: 2.35))
        #expect(abs(km - 5_556) < 15)
    }
}

@Suite("Journey planner")
struct JourneyPlannerTests {
    private let journey = JourneyPlanner.plan(Routes.almatyToParis, cities: nil)

    @Test func startsAtHomeEndsAtTheDream() {
        #expect(journey.stops.first?.kind == .home)
        #expect(journey.stops.last?.kind == .dream)
        #expect(journey.dream?.name == "Paris")
    }

    @Test func stopsRiseAndAreNeverFarApartOnLand() {
        let kms = journey.stops.map(\.km)
        #expect(kms == kms.sorted())
        for (a, b) in zip(journey.stops, journey.stops.dropFirst()) where !journey.isOnWater(atKm: (a.km + b.km) / 2) {
            // Rest stops keep every gap over land within a long day's walk and a bit.
            #expect(b.km - a.km <= 15 * 1.3 + 0.01, "gap \(b.km - a.km) after \(a.name)")
        }
    }

    @Test func theCaspianIsCrossedByWater() {
        #expect(journey.crossings.count == 1)
        let crossing = journey.crossings[0]
        #expect(crossing.upperBound - crossing.lowerBound > 200)
        #expect(journey.isOnWater(atKm: crossing.lowerBound + 50))
        #expect(!journey.isOnWater(atKm: crossing.lowerBound - 50))
    }

    @Test func nextAndLastStops() {
        let km = 5.0
        let next = journey.nextStop(after: km)
        let last = journey.lastStop(atOrBefore: km)
        #expect(next != nil && next!.km > km)
        #expect(last != nil && last!.km <= km)
        #expect(journey.stops(passedFrom: 0, to: 10).allSatisfy { $0.km > 0 && $0.km <= 10 })
    }

    @Test func countriesLightUpAlongTheWay() {
        #expect(journey.countries(upTo: 1) == ["KZ"])
        #expect(journey.countries(upTo: journey.totalKm).isSuperset(of: ["KZ", "UZ", "TR", "FR"]))
    }
}

@Suite("Height ladder")
struct HeightLadderTests {
    @Test func startsEasy() {
        let state = HeightLadder.state(metres: 0)
        #expect(state.current.id == "house")
        #expect(state.conquered.isEmpty)
        #expect(HeightLadder.summits.first!.floors == 5)
    }

    @Test func fillsTheSummitBeingClimbed() {
        let state = HeightLadder.state(metres: 200)
        #expect(state.conquered.map(\.id) == ["house", "wheel", "bayterek"])
        #expect(state.current.id == "eiffel")
        #expect(abs(state.fill - 200.0 / 330) < 1e-9)
    }

    @Test func pastEverestCountsEverests() {
        let state = HeightLadder.state(metres: 8_849 * 2.5)
        #expect(state.current.id == "everest")
        #expect(state.everests == 2)
        #expect(abs(state.fill - 0.5) < 1e-9)
    }

    @Test func conqueredBetween() {
        #expect(HeightLadder.conquered(from: 50, to: 400).map(\.id) == ["wheel", "bayterek", "eiffel"])
        #expect(HeightLadder.conquered(from: 400, to: 400).isEmpty)
    }
}

@Suite("Weekly goal and streak")
struct WeeklyGoalTests {
    @Test func aLittleMoreThanUsual() {
        let goal = WeeklyGoal.pick(usualWeekKm: 30)
        #expect(goal.course.km >= 33)
        #expect(goal.course.km <= 33 * 1.12)
    }

    @Test func aFirstWeekWithoutHistoryIsShort() {
        #expect(WeeklyGoal.pick(usualWeekKm: nil).course.km <= 20)
    }

    @Test func coursesGrow() {
        let kms = WeeklyGoal.courses.map(\.km)
        #expect(kms == kms.sorted())
    }

    @Test func streakCountsClosedWeeksSinceInstall() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 12))!
        let goal = WeeklyGoal(course: WeeklyGoal.courses[0])
        // 4 km a day for five weeks: 28 km a week, enough for 12 km.
        let start = calendar.date(byAdding: .day, value: -35, to: calendar.startOfDay(for: now))!
        let days = (0...35).map { offset in
            ActivityDay(date: calendar.date(byAdding: .day, value: offset, to: start)!, steps: 5_400, distanceKm: 4, floors: 5, activeKcal: nil)
        }
        let history = ActivityHistory(days: days, calendar: calendar)
        let installedThreeWeeksAgo = calendar.date(byAdding: .day, value: -21, to: now)!
        let streak = WeekStreak(history: history, installDate: installedThreeWeeksAgo, goal: goal, now: now)
        #expect(streak.thisWeekClosed)
        #expect(streak.weeks >= 3 && streak.weeks <= 4)
    }
}

@Suite("Since last time")
struct SinceLastTimeTests {
    @Test func reportsWhatWasPassed() throws {
        let calendar = Calendar.current
        let journey = JourneyPlanner.plan(Routes.almatyToParis, cities: nil)
        let install = calendar.date(byAdding: .day, value: -3, to: .now)!
        let days = (0...3).map { offset in
            ActivityDay(date: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3 + offset, to: .now)!), steps: 8_000, distanceKm: 6, floors: 12, activeKcal: nil)
        }
        let history = ActivityHistory(days: days, calendar: calendar)
        let snapshot = ProgressSnapshot(history: history, installDate: install, journeyRoute: journey)
        #expect(abs(snapshot.routeKm - 24) < 1e-9)
        // 48 floors = 144 m: past the house, the wheel and Bayterek.
        #expect(snapshot.ladder.current.id == "eiffel")

        let seen = SeenProgress(km: 10, metres: 50, steps: 15_000, date: .now)
        let scene = SinceLastTime(seen: seen, now: snapshot, journey: journey)
        #expect(abs(scene.addedKm - 14) < 1e-9)
        #expect(scene.isWorthShowing)
        #expect(scene.summitsConquered.map(\.id) == ["wheel", "bayterek"])
        #expect(scene.stopsPassed.allSatisfy { $0.km > 10 && $0.km <= 24 })
        #expect(scene.milestones.map(\.id) == ["half"])
        #expect(try #require(scene.nextStop).km > 24)
    }

    @Test func nothingNewIsNotWorthAScene() {
        let journey = JourneyPlanner.plan(Routes.almatyToParis, cities: nil)
        let today = Calendar.current.startOfDay(for: .now)
        let history = ActivityHistory(days: [ActivityDay(date: today, steps: 1_000, distanceKm: 0.7, floors: 0, activeKcal: nil)])
        let snapshot = ProgressSnapshot(history: history, installDate: .now, journeyRoute: journey)
        let seen = SeenProgress(km: snapshot.routeKm, metres: 0, steps: 1_000, date: .now)
        #expect(!SinceLastTime(seen: seen, now: snapshot, journey: journey).isWorthShowing)
    }
}

@Suite("Energy")
struct EnergyTests {
    @Test func estimateScalesWithWeight() {
        #expect(abs(EnergyEstimate.kcal(steps: 10_000, bodyMassKg: nil) - 400) < 1e-9)
        #expect(EnergyEstimate.kcal(steps: 10_000, bodyMassKg: 90) > 400)
    }

    @Test func historyFillsMissingEnergy() {
        let day = ActivityDay(date: .now, steps: 5_000, distanceKm: 3.7, floors: 3, activeKcal: nil)
        let totals = ActivityHistory(days: [day]).totals(from: .distantPast, to: .distantFuture)
        #expect(abs(totals.activeKcal - 200) < 1e-9)
        #expect(totals.metresClimbed == 9)
    }
}
