import SwiftUI

/// Numbers as the screens show them.
enum Format {
    /// "4.8" below 100 km, "1,284" above: a decimal stops mattering.
    static func km(_ km: Double) -> String {
        km < 100
            ? km.formatted(.number.precision(.fractionLength(1)))
            : km.formatted(.number.precision(.fractionLength(0)))
    }

    /// Walking at about 4.8 km/h.
    static func walkingMinutes(_ km: Double) -> Int {
        max(1, Int((km / 4.8 * 60).rounded()))
    }
}

/// The small uppercase label above a card's content.
struct Eyebrow: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.white.opacity(0.55))
    }
}

/// A slim progress bar in the sunrise gradient.
struct SunriseBar: View {
    let progress: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.ember, Palette.accent, Palette.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, proxy.size.width * min(1, max(0, progress))))
                    .shadow(color: Palette.accent.opacity(0.6), radius: 6)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

extension JourneyStop {
    /// What a card calls it: the place's name, or "Rest stop" between towns.
    var title: String {
        kind == .restStop ? String(localized: "Rest stop") : displayName()
    }

    /// The line under the title: a rest stop's region and the town it's heading for, a
    /// town's region.
    var subtitle: String? {
        switch kind {
        case .restStop:
            let region = displayName()
            guard let ahead = displayArea() else { return region }
            return "\(region) → \(ahead)"
        case .shore:
            return String(localized: "The water starts here")
        default:
            return displayArea()
        }
    }
}
