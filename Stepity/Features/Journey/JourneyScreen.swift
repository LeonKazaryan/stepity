import SwiftUI

/// The journey: the globe with the trail from home, the walker on it, the next stop up top
/// and the three things closest to done at the bottom. After a walk, "since last time" plays
/// over it first.
struct JourneyScreen: View {
    let model: AppModel

    var body: some View {
        ZStack {
            GlobeView(controller: model.globe)
                .ignoresSafeArea()

            if let scene = model.pendingScene {
                SinceLastTimeScene(scene: scene, model: model) {
                    model.markSeen()
                    withAnimation(Motion.smooth) { model.pendingScene = nil }
                }
                .transition(.opacity)
            } else if let journey = model.journey, let snapshot = model.snapshot {
                VStack {
                    NextStopCard(journey: journey, km: snapshot.routeKm)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                    ProgressBars(journey: journey, snapshot: snapshot)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 76)
                }
                .transition(.opacity)
            }
        }
        .task(id: model.pendingScene == nil) {
            guard model.pendingScene == nil else { return }
            model.showJourneyOnGlobe()
            try? await Task.sleep(for: .seconds(0.8))
            model.globe.focusOnWalker(zoom: 5)
        }
    }
}

/// "Next: Kaskelen · 3.2 km more", with the bar from the last stop to the next.
private struct NextStopCard: View {
    let journey: Journey
    let km: Double

    var body: some View {
        let next = journey.nextStop(after: km)
        let last = journey.lastStop(atOrBefore: km)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Next stop")
                Spacer()
                Text("\(Format.km(km)) km from home")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            if let next {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: next.title)
                        .font(Typography.title)
                        .foregroundStyle(.white)
                    if let subtitle = next.subtitle {
                        Text(verbatim: subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                let left = next.km - km
                Text("\(Format.km(left)) km more · about \(Format.walkingMinutes(left)) min")
                    .font(Typography.label)
                    .foregroundStyle(Palette.gold)
                let span = next.km - (last?.km ?? 0)
                SunriseBar(progress: span > 0 ? (km - (last?.km ?? 0)) / span : 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// The three bars that are always nearly full: the next stop, the summit being climbed, the
/// week's goal.
private struct ProgressBars: View {
    let journey: Journey
    let snapshot: ProgressSnapshot

    var body: some View {
        let km = snapshot.routeKm
        let next = journey.nextStop(after: km)
        let lastKm = journey.lastStop(atOrBefore: km)?.km ?? 0
        let stopFill = next.map { $0.km > lastKm ? (km - lastKm) / ($0.km - lastKm) : 0 } ?? 1
        HStack(spacing: 10) {
            Pill(symbol: "mappin.and.ellipse", title: Text(verbatim: next?.title ?? ""), fill: stopFill)
            Pill(symbol: "mountain.2.fill", title: Text(snapshot.ladder.current.name), fill: snapshot.ladder.fill)
            Pill(symbol: "flag.fill", title: Text("Week"), fill: snapshot.goalFill)
        }
    }

    private struct Pill: View {
        let symbol: String
        let title: Text
        let fill: Double

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.gold)
                    Text(fill, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                }
                title
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                SunriseBar(progress: fill, height: 5)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
        }
    }
}
