import Foundation

/// The little Stepity remembers between launches: when the journey started and what the user
/// saw last. Health data itself is never stored, only read again (App Review 5.1.3: no health
/// data in iCloud, and none needs to be kept here either). On this device only.
@MainActor
@Observable
final class JourneyStore {
    private let defaults: UserDefaults

    /// The morning the journey started: the first launch after onboarding.
    private(set) var installDate: Date?
    /// What the last "since last time" scene ended on.
    private(set) var seen: SeenProgress?
    /// Show food in "Today", or energy as phone charges instead.
    var showsFood: Bool {
        didSet { defaults.set(showsFood, forKey: Keys.showsFood) }
    }

    var hasStarted: Bool { installDate != nil }

    private enum Keys {
        static let installDate = "journey.installDate"
        static let seen = "journey.seen"
        static let showsFood = "today.showsFood"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installDate = defaults.object(forKey: Keys.installDate) as? Date
        seen = (defaults.data(forKey: Keys.seen)).flatMap { try? JSONDecoder().decode(SeenProgress.self, from: $0) }
        showsFood = defaults.object(forKey: Keys.showsFood) as? Bool ?? true
    }

    /// The journey begins: today's steps from midnight already count.
    func start(on date: Date = .now) {
        installDate = date
        defaults.set(date, forKey: Keys.installDate)
    }

    func markSeen(_ progress: SeenProgress) {
        seen = progress
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: Keys.seen) }
    }

    func reset() {
        installDate = nil
        seen = nil
        defaults.removeObject(forKey: Keys.installDate)
        defaults.removeObject(forKey: Keys.seen)
    }

    #if DEBUG
    /// For DEBUG runs: pretend the journey started `days` ago, and that the user last looked
    /// `kmAgo` kilometres back.
    func debugOverride(installedDaysAgo days: Int?, seenKmAgo kmAgo: Double?, currentKm: Double?, currentMetres: Double?, currentSteps: Int?) {
        if let days {
            installDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)
        }
        if let kmAgo, let currentKm {
            seen = SeenProgress(km: max(0, currentKm - kmAgo), metres: max(0, (currentMetres ?? 0) - kmAgo * 9), steps: max(0, (currentSteps ?? 0) - Int(kmAgo * 1350)), date: .now.addingTimeInterval(-3 * 3600))
        }
    }
    #endif
}
