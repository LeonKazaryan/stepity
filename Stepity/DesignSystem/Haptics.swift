import SwiftUI
import UIKit

/// Haptic vocabulary: each event has exactly one feel, used everywhere.
/// Use with `.sensoryFeedback(Haptics.select, trigger: …)`. The system respects the
/// user's haptics setting on its own.
enum Haptics {
    /// Picking something: a tab, a food.
    static let select = SensoryFeedback.selection
    /// A light confirmation on a button.
    static let tap = SensoryFeedback.impact(weight: .light)
    /// Something conquered: a summit, a milestone, a city.
    static let conquest = SensoryFeedback.success
    /// A stamp lands in the collection.
    static let stamp = SensoryFeedback.impact(weight: .heavy)
    /// A letter of the welcome title lands: barely there.
    static let letter = SensoryFeedback.impact(weight: .light, intensity: 0.35)
}

/// Haptics played from code, many in a row: the tick of each stop the line passes, each chip
/// landing on the pile. Generators are prepared once and reused, as UIKit asks.
@MainActor
enum HapticPlayer {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    private static var lastTick = Date.distantPast

    static func prepare() {
        light.prepare()
        soft.prepare()
        rigid.prepare()
        heavy.prepare()
    }

    /// A stop passed, a digit rolled: small and crisp. At most one every 40 ms, so a burst
    /// of stops reads as a purr, not mush.
    static func tick(_ intensity: Double = 0.6) {
        let now = Date()
        guard now.timeIntervalSince(lastTick) > 0.04 else { return }
        lastTick = now
        rigid.impactOccurred(intensity: max(0.1, min(1, intensity)))
    }

    /// Something soft landing: a chip on the pile.
    static func land(_ intensity: Double = 0.5) {
        soft.impactOccurred(intensity: max(0.1, min(1, intensity)))
    }

    /// A city reached on the way.
    static func arrive() {
        heavy.impactOccurred(intensity: 0.8)
    }

    /// A summit or milestone conquered.
    static func conquest() {
        notification.notificationOccurred(.success)
    }

    /// The stamp slamming into the collection.
    static func stamp() {
        heavy.impactOccurred(intensity: 1)
    }
}
