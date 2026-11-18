import Foundation
import Observation

/// The app's state: where the user is in onboarding, the history, the route and the progress
/// on it. One globe, shared by every screen that shows it.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case loading
        /// The first screen: what Stepity is, and the Health permission.
        case welcome
        /// A lifetime of steps flies over the globe, once.
        case prologue
        /// "That was before us. The new path starts today."
        case newPath
        case main
    }

    enum Tab: Hashable {
        case today, week, journey
    }

    var phase = Phase.loading
    var tab = Tab.journey
    let store = JourneyStore()
    let globe = GlobeController(style: .stepity)

    private(set) var history: ActivityHistory?
    /// Home to the dream: the journey since the install.
    private(set) var journey: Journey?
    /// The same road, much longer: for the prologue's lifetime of steps.
    private(set) var prologueRoute: Journey?
    private(set) var snapshot: ProgressSnapshot?
    /// Waiting to play when the journey screen shows.
    var pendingScene: SinceLastTime?
    private(set) var bodyMassKg: Double?

    private let source: ActivitySource
    private var isRefreshing = false

    init() {
        source = Self.makeSource()
        #if DEBUG
        if Debug.flag("StepityDebugReset") { store.reset() }
        #endif
    }

    private static func makeSource() -> ActivitySource {
        #if targetEnvironment(simulator)
        return DemoActivitySource(extraStepsToday: Debug.int("StepityDebugExtraSteps") ?? 0)
        #else
        #if DEBUG
        if Debug.flag("StepityDebugDemo") { return DemoActivitySource(extraStepsToday: Debug.int("StepityDebugExtraSteps") ?? 0) }
        #endif
        return HealthActivitySource()
        #endif
    }

    // MARK: - Launch

    func launch() async {
        await planRoutes()
        #if DEBUG
        if let days = Debug.int("StepityDebugInstalledDaysAgo") {
            store.debugOverride(installedDaysAgo: days, seenKmAgo: nil, currentKm: nil, currentMetres: nil, currentSteps: nil)
        }
        #endif
        if store.hasStarted {
            await refresh()
            #if DEBUG
            if let kmAgo = Debug.double("StepityDebugSeenKmAgo"), let snapshot {
                store.debugOverride(installedDaysAgo: nil, seenKmAgo: kmAgo, currentKm: snapshot.routeKm, currentMetres: snapshot.journey.metresClimbed, currentSteps: snapshot.journey.steps)
                prepareScene()
            }
            #endif
            phase = .main
        } else {
            phase = .welcome
        }
        #if DEBUG
        applyDebugScreen()
        #endif
    }

    /// The city list and both routes, off the main thread: a tenth of a second on a phone.
    private func planRoutes() async {
        guard journey == nil else { return }
        let planned = await Task.detached(priority: .userInitiated) { () -> (Journey, Journey) in
            let cities = Bundle.main.url(forResource: "cities", withExtension: "nmcity").flatMap { url in
                try? CityTable(compressed: Data(contentsOf: url, options: .mappedIfSafe))
            }
            let journey = JourneyPlanner.plan(Routes.almatyToParis, cities: cities)
            let prologue = JourneyPlanner.plan(Routes.prologueFromAlmaty, cities: nil)
            return (journey, prologue)
        }.value
        journey = planned.0
        prologueRoute = planned.1
    }

    // MARK: - Onboarding

    /// "Let's go" on the welcome screen: ask Health, read the history, play the prologue.
    func requestHealth() async {
        _ = await source.requestAccess()
        await loadHistory()
        phase = .prologue
    }

    /// The prologue is over: the journey starts this morning.
    func startJourney() async {
        store.start()
        await refresh()
        phase = .newPath
    }

    func finishOnboarding() {
        markSeen()
        phase = .main
        tab = .journey
    }

    // MARK: - Progress

    /// Reads Health again and works out everything. On every return to the app.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadHistory()
        guard let history, let journey, let installDate = store.installDate else { return }
        snapshot = ProgressSnapshot(history: history, installDate: installDate, journeyRoute: journey, bodyMassKg: bodyMassKg)
    }

    /// After a refresh in the main app: queue "since last time" if there's something to show.
    func prepareScene() {
        guard let snapshot, let journey else { return }
        let seen = store.seen ?? SeenProgress(km: snapshot.routeKm, metres: snapshot.journey.metresClimbed, steps: snapshot.journey.steps, date: .now)
        let scene = SinceLastTime(seen: seen, now: snapshot, journey: journey)
        pendingScene = scene.isWorthShowing ? scene : nil
        if pendingScene == nil { markSeen() }
    }

    /// The scene played (or there was nothing new): next time starts from here.
    func markSeen() {
        guard let snapshot else { return }
        store.markSeen(SeenProgress(km: snapshot.routeKm, metres: snapshot.journey.metresClimbed, steps: snapshot.journey.steps, date: .now))
    }

    private func loadHistory() async {
        let start = Calendar.current.date(byAdding: .year, value: -12, to: .now) ?? .distantPast
        if let days = try? await source.days(from: start) {
            history = ActivityHistory(days: days)
        }
        if bodyMassKg == nil { bodyMassKg = await source.bodyMassKg() }
    }

    // MARK: - Globe

    /// Puts the journey on the globe with the walker where they are now (or where they were
    /// last seen, when a scene is about to play from there).
    func showJourneyOnGlobe(atKm km: Double? = nil) {
        guard let journey else { return }
        let progress = km ?? snapshot?.routeKm ?? 0
        globe.setTrail(journey.path, stops: journey.trailStops, progressKm: progress)
        globe.setTrailGlow(snapshot?.streak.glow ?? 1)
        globe.setVisited(journey.countries(upTo: progress))
    }

    /// The prologue's road with the walker at home: the line will grow over a lifetime of steps.
    func showPrologueOnGlobe() {
        guard let route = prologueRoute else { return }
        globe.setVisited([])
        globe.setTrail(route.path, stops: route.trailStops.filter(\.isMajor), progressKm: 0)
        globe.setTrailGlow(2)
    }

    /// The prologue in numbers: since when, how far, where that would be, how high.
    var prologue: Prologue? {
        guard let history, let route = prologueRoute else { return nil }
        let lifetime = history.lifetime
        let km = lifetime.distanceKm
        let onRoute = min(km, route.totalKm)
        return Prologue(
            since: history.firstActiveDay,
            km: km,
            routeKm: onRoute,
            place: route.lastPlace(atOrBefore: onRoute),
            isOnWater: route.isOnWater(atKm: onRoute),
            everests: lifetime.metresClimbed / 8_849,
            beyondRouteKm: max(0, km - route.totalKm)
        )
    }

    struct Prologue {
        let since: Date?
        let km: Double
        let routeKm: Double
        let place: JourneyStop?
        let isOnWater: Bool
        let everests: Double
        let beyondRouteKm: Double
    }

    #if DEBUG
    private func applyDebugScreen() {
        switch Debug.string("StepityDebugScreen") {
        case "welcome": phase = .welcome
        case "prologue": Task { await requestHealth() }
        case "today": phase = .main; tab = .today
        case "week": phase = .main; tab = .week
        case "journey": phase = .main; tab = .journey
        default: break
        }
    }
    #endif
}

/// Launch arguments for DEBUG runs and screenshots (`CLAUDE.md`).
enum Debug {
    static func string(_ key: String) -> String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key)
        #else
        nil
        #endif
    }

    static func flag(_ key: String) -> Bool { string(key).map { $0 == "YES" || $0 == "1" || $0 == "true" } ?? false }
    static func int(_ key: String) -> Int? { string(key).flatMap(Int.init) }
    static func double(_ key: String) -> Double? { string(key).flatMap(Double.init) }
}
