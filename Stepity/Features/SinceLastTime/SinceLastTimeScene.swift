import SwiftUI

/// "Since last time": the few seconds after a walk that the whole app is for. The steps count
/// up, the line grows from where the user last looked with the camera riding along, every
/// stop ticks in the hand, the summit and the week fill up, and anything conquered gets its
/// moment. Ends on the next stop: a reason to go out again. A tap skips to the end.
struct SinceLastTimeScene: View {
    let scene: SinceLastTime
    let model: AppModel
    let onFinish: () -> Void

    private enum Step: Int, Comparable {
        case counting, walking, climbing, conquest, next
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var step = Step.counting
    @State private var stepsShown = 0
    @State private var kmShown = 0.0
    /// The latest town or city passed, shown as a toast while the line grows.
    @State private var arrival: JourneyStop?
    @State private var arrivalCount = 0
    @State private var summitFill = 0.0
    @State private var goalFill = 0.0
    @State private var bursts: [ConfettiBurst] = []
    @State private var script: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var summitNow: HeightLadder.State { HeightLadder.state(metres: scene.toMetres) }
    private var summitBefore: HeightLadder.State { HeightLadder.state(metres: scene.fromMetres) }

    var body: some View {
        ZStack {
            // Darken top and bottom so the text reads, keep the globe clear in the middle.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.65), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.75), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                if let arrival, step == .walking {
                    ArrivalToast(stop: arrival)
                        .id(arrivalCount)
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                        .padding(.top, 14)
                }
                Spacer()
                bottomCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }

            ConfettiView(bursts: bursts)
        }
        .contentShape(Rectangle())
        .onTapGesture { if step < .next { skip() } }
        .task { play() }
        .onDisappear {
            script?.cancel()
            model.globe.onTrailStopPassed = nil
        }
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 4) {
            Eyebrow(text: "Since last time")
            Text("+\(stepsShown.formatted()) steps")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: Double(stepsShown)))
                .foregroundStyle(.white)
            Text("+\(Format.km(kmShown)) km along the way")
                .font(Typography.headline)
                .contentTransition(.numericText(value: kmShown))
                .foregroundStyle(Palette.gold)
        }
        .shadow(color: .black.opacity(0.4), radius: 8)
    }

    @ViewBuilder
    private var bottomCard: some View {
        switch step {
        case .counting, .walking:
            EmptyView()
        case .climbing:
            climbingCard.transition(.move(edge: .bottom).combined(with: .opacity))
        case .conquest:
            conquestCard.transition(.scale(scale: 0.7).combined(with: .opacity))
        case .next:
            nextCard.transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var climbingCard: some View {
        HStack(spacing: 16) {
            SummitFill(summit: summitNow.current, fill: summitFill, showsPercent: false)
                .frame(width: 74, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Climbing")
                Text(summitNow.current.name)
                    .font(Typography.title)
                    .foregroundStyle(.white)
                Text(summitFill, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .contentTransition(.numericText(value: summitFill))
                    .foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.goalCourseName)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    SunriseBar(progress: goalFill, height: 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard()
    }

    private var conquestCard: some View {
        VStack(spacing: 10) {
            Eyebrow(text: "Conquered")
            if let summit = scene.summitsConquered.last {
                SummitFill(summit: summit, fill: 1, showsPercent: false)
                    .frame(width: 96, height: 124)
                Text(summit.name)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
            } else if let milestone = scene.milestones.last {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Palette.sunriseGradient)
                Text(milestone.name)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Text("Into your collection")
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let next = scene.nextStop {
                Eyebrow(text: "Next stop")
                Text(verbatim: next.title)
                    .font(Typography.title)
                    .foregroundStyle(.white)
                let left = next.km - scene.toKm
                Text("\(Format.km(left)) km more · about \(Format.walkingMinutes(left)) min of walking")
                    .font(Typography.label)
                    .foregroundStyle(Palette.gold)
            } else {
                Text("You made it to your dream")
                    .font(Typography.title)
                    .foregroundStyle(.white)
            }
            Button("Continue", action: finish)
                .buttonStyle(.capsule(.accent))
                .padding(.top, 4)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Script

    private func play() {
        HapticPlayer.prepare()
        let globe = model.globe
        model.showJourneyOnGlobe(atKm: scene.fromKm)
        globe.setVisited(model.journey?.countries(upTo: scene.fromKm) ?? [])
        globe.focusOnWalker(zoom: followZoom)
        summitFill = summitBefore.current == summitNow.current ? summitBefore.fill : 0
        goalFill = scene.goalBefore

        globe.onTrailStopPassed = { index in
            guard let stop = model.journey?.stops[safe: index] else { return }
            if stop.kind == .restStop {
                HapticPlayer.tick(0.45)
            } else {
                HapticPlayer.arrive()
                withAnimation(Motion.bouncy) {
                    arrival = stop
                    arrivalCount += 1
                }
            }
        }

        script = Task { @MainActor in
            if reduceMotion {
                skip()
                return
            }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 1.1)) {
                stepsShown = scene.steps
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }

            step = .walking
            let duration = min(5.5, max(2.4, 1.8 + scene.addedKm * 0.06))
            globe.growTrail(to: scene.toKm, duration: duration, followZoom: followZoom)
            withAnimation(.easeInOut(duration: duration)) { kmShown = scene.addedKm }
            try? await Task.sleep(for: .seconds(duration + 0.3))
            guard !Task.isCancelled else { return }
            globe.setVisited(model.journey?.countries(upTo: scene.toKm) ?? [])

            withAnimation(Motion.smooth) { step = .climbing }
            try? await Task.sleep(for: .seconds(0.4))
            HapticPlayer.tick(0.7)
            summitFill = summitNow.fill
            withAnimation(.spring(duration: 1.4, bounce: 0.1)) { goalFill = scene.goalAfter }
            try? await Task.sleep(for: .seconds(1.9))
            guard !Task.isCancelled else { return }

            if !scene.summitsConquered.isEmpty || !scene.milestones.isEmpty {
                withAnimation(Motion.celebrate) { step = .conquest }
                HapticPlayer.conquest()
                celebrate()
                try? await Task.sleep(for: .seconds(0.5))
                HapticPlayer.stamp()
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
            }
            withAnimation(Motion.smooth) { step = .next }
        }
    }

    private func skip() {
        script?.cancel()
        stepsShown = scene.steps
        kmShown = scene.addedKm
        model.globe.setTrailProgress(scene.toKm)
        model.globe.setVisited(model.journey?.countries(upTo: scene.toKm) ?? [])
        model.globe.focusOnWalker(zoom: followZoom)
        summitFill = summitNow.fill
        goalFill = scene.goalAfter
        withAnimation(Motion.smooth) { step = .next }
    }

    private func finish() {
        model.globe.onTrailStopPassed = nil
        onFinish()
    }

    private func celebrate() {
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.62)
        bursts.append(ConfettiBurst(origin: center, colors: [Palette.accent, Palette.gold, Palette.ember, .white]))
    }

    /// Closer for a short walk, farther for a long one, so the whole stretch fits on screen.
    private var followZoom: Double {
        switch scene.addedKm {
        case ..<3: 10
        case ..<15: 7
        case ..<80: 4.5
        default: 2.2
        }
    }
}

/// A town reached on the way, popping up under the counter.
private struct ArrivalToast: View {
    let stop: JourneyStop

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: stop.isMajor ? "star.fill" : "mappin.circle.fill")
                .foregroundStyle(Palette.gold)
            Text(verbatim: stop.title)
                .font(Typography.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glass(Capsule())
    }
}

extension SinceLastTime {
    var goalCourseName: LocalizedStringResource { goalCourse.name }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
