import Foundation
import HealthKit

/// Where the days come from: Apple Health on a device, a made-up history in the simulator
/// and in DEBUG runs (`-StepityDebugDemo YES`).
protocol ActivitySource: Sendable {
    /// Asks for read access once. Health never says whether reading was allowed: a "no" just
    /// looks like no data.
    func requestAccess() async -> Bool
    /// Every day from `start` to today, oldest first, no gaps.
    func days(from start: Date) async throws -> [ActivityDay]
    /// The latest weight in Health, for the energy estimate.
    func bodyMassKg() async -> Double?
}

/// Reads Apple Health. Never writes.
struct HealthActivitySource: ActivitySource {
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.bodyMass),
    ]

    func requestAccess() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            return true
        } catch {
            return false
        }
    }

    func days(from start: Date) async throws -> [ActivityDay] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: start)
        let end = Date.now
        async let steps = dailySums(.stepCount, unit: .count(), from: first, to: end)
        async let distance = dailySums(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: first, to: end)
        async let floors = dailySums(.flightsClimbed, unit: .count(), from: first, to: end)
        async let energy = dailySums(.activeEnergyBurned, unit: .kilocalorie(), from: first, to: end)
        let (s, d, f, e) = try await (steps, distance, floors, energy)

        var days: [ActivityDay] = []
        var day = first
        while day <= end {
            days.append(ActivityDay(
                date: day,
                steps: Int(s[day] ?? 0),
                distanceKm: d[day] ?? 0,
                floors: Int(f[day] ?? 0),
                activeKcal: e[day]
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    func bodyMassKg() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Sums of one quantity per calendar day, keyed by the day's midnight.
    private func dailySums(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let type = HKQuantityType(identifier)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let quantity = statistics.sumQuantity() {
                sums[statistics.startDate] = quantity.doubleValue(for: unit)
            }
        }
        return sums
    }
}

/// A believable made-up history: years of walking with weekends, seasons, lazy days and
/// long walks, the same every run. Today grows through the day like a real one.
struct DemoActivitySource: ActivitySource {
    /// The first day of the made-up history.
    var since: Date = {
        var components = DateComponents()
        components.year = 2021
        components.month = 2
        components.day = 1
        return Calendar.current.date(from: components) ?? .distantPast
    }()
    /// Extra steps today, to try "since last time" without walking.
    var extraStepsToday = 0

    func requestAccess() async -> Bool { true }

    func bodyMassKg() async -> Double? { 72 }

    func days(from start: Date) async throws -> [ActivityDay] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: max(start, since))
        let today = calendar.startOfDay(for: .now)
        var days: [ActivityDay] = []
        var day = first
        while day <= today {
            days.append(Self.day(day, calendar: calendar, isToday: day == today, extraSteps: extraStepsToday))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    static func day(_ date: Date, calendar: Calendar, isToday: Bool, extraSteps: Int) -> ActivityDay {
        let index = Int(date.timeIntervalSinceReferenceDate / 86_400)
        var random = SplitMix64(seed: (UInt64(bitPattern: Int64(index)) &* 0xD1B5_4A32_D192_ED03) ^ 0x5DEE_CE66_D1CE_4E5B)
        // Neighbouring days' seeds differ by a constant: skip the first draw so they don't echo.
        _ = random.next()
        let weekday = calendar.component(.weekday, from: date)
        let month = calendar.component(.month, from: date)
        var steps = 5_400.0
        steps *= weekday == 7 ? 1.3 : weekday == 1 ? 0.95 : 1
        steps *= [0.8, 0.82, 0.92, 1.02, 1.1, 1.15, 1.18, 1.15, 1.08, 1.0, 0.9, 0.85][month - 1]
        steps *= Double.random(in: 0.7...1.3, using: &random)
        let roll = Double.random(in: 0..<1, using: &random)
        if roll < 0.08 { steps *= 0.35 } else if roll > 0.95 { steps *= 2.1 }
        var floors = Int(Double.random(in: 3...13, using: &random))

        if isToday {
            // The day so far: nothing before 7, everything by 22.
            let hour = Double(calendar.component(.hour, from: .now)) + Double(calendar.component(.minute, from: .now)) / 60
            let share = min(1, max(0.05, (hour - 7) / 15))
            steps = steps * share
            floors = Int(Double(floors) * share)
            steps += Double(extraSteps)
        }
        let count = Int(steps)
        return ActivityDay(date: date, steps: count, distanceKm: Double(count) * 0.00074, floors: floors, activeKcal: nil)
    }
}
