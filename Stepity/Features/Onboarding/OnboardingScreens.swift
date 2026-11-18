import SwiftUI

/// The first screen: the name rising letter by letter over a slowly turning globe, three lines
/// on what this is, and one button that asks Health.
struct WelcomeScreen: View {
    let model: AppModel
    @State private var letters = 0
    @State private var isAsking = false
    private static let title = Array("Stepity")

    var body: some View {
        ZStack {
            GlobeView(controller: model.globe)
                .ignoresSafeArea()
                .opacity(0.55)
                .allowsHitTesting(false)
            LinearGradient(colors: [.clear, Palette.night.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(Array(Self.title.enumerated()), id: \.offset) { index, letter in
                        Text(verbatim: String(letter))
                            .opacity(index < letters ? 1 : 0)
                            .offset(y: index < letters ? 0 : 24)
                    }
                }
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.sunriseGradient)
                .shadow(color: Palette.accent.opacity(0.5), radius: 18)
                .sensoryFeedback(Haptics.letter, trigger: letters)

                VStack(alignment: .leading, spacing: 14) {
                    Feature(symbol: "globe.europe.africa.fill", text: "Your steps draw a line across the world, from your home to your dream")
                    Feature(symbol: "mountain.2.fill", text: "Floors climb towers and mountains, from Bayterek to Everest")
                    Feature(symbol: "sparkles", text: "After every walk, see what changed")
                }
                .padding(.horizontal, 8)

                Button {
                    isAsking = true
                    Task { await model.requestHealth() }
                } label: {
                    if isAsking { ProgressView().tint(.white) } else { Text("Let's go") }
                }
                .buttonStyle(.capsule(.accent))
                .disabled(isAsking)

                Label("Read from Health only. Nothing leaves your iPhone.", systemImage: "lock.fill")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(24)
        }
        .task {
            for index in 1...Self.title.count {
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(Motion.bouncy) { letters = index }
            }
        }
    }

    private struct Feature: View {
        let symbol: String
        let text: LocalizedStringKey

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 28)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A lifetime of steps, once: the line flies from home across the world while the counter
/// runs, and lands where all those steps would have taken you. Then it's put aside: the
/// journey itself starts today.
struct PrologueScreen: View {
    let model: AppModel
    @State private var isDone = false

    var body: some View {
        ZStack {
            GlobeView(controller: model.globe)
                .ignoresSafeArea()
            LinearGradient(stops: [
                .init(color: .black.opacity(0.7), location: 0),
                .init(color: .clear, location: 0.32),
                .init(color: .clear, location: 0.6),
                .init(color: .black.opacity(0.8), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if let prologue = model.prologue {
                VStack(spacing: 6) {
                    Eyebrow(text: sinceText(prologue.since))
                    // Follows the line as it grows: read straight from the globe every frame.
                    TimelineView(.animation(paused: isDone)) { _ in
                        let km = isDone ? prologue.km : min(prologue.km, model.globe.trail?.progressKm ?? 0)
                        Text("\(Format.km(km)) km")
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    Text("on foot")
                        .font(Typography.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if isDone {
                        result(prologue)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task { await play() }
    }

    private func result(_ prologue: AppModel.Prologue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if prologue.isOnWater, let place = prologue.place {
                Text("You'd be out at sea, past \(place.displayName())")
                    .font(Typography.title)
                    .foregroundStyle(.white)
            } else if prologue.isOnWater {
                Text("You'd be in the middle of the ocean")
                    .font(Typography.title)
                    .foregroundStyle(.white)
            } else if let place = prologue.place {
                Text("You'd be in \(place.displayName())")
                    .font(Typography.title)
                    .foregroundStyle(.white)
            }
            if prologue.everests >= 0.1 {
                Label {
                    Text("and up \(prologue.everests.formatted(.number.precision(.fractionLength(1)))) Everests of stairs")
                } icon: {
                    Image(systemName: "mountain.2.fill").foregroundStyle(Palette.gold)
                }
                .font(Typography.headline)
                .foregroundStyle(.white.opacity(0.85))
            }
            ShareLink(item: shareText(prologue)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.capsule(.subtle))
            Button("That was before. Start the journey") {
                Task { await model.startJourney() }
            }
            .buttonStyle(.capsule(.accent))
        }
        .padding(18)
        .glassCard()
    }

    private func play() async {
        model.showPrologueOnGlobe()
        guard let prologue = model.prologue else { return }
        model.globe.focusOnWalker(zoom: 3)
        try? await Task.sleep(for: .seconds(1.6))
        HapticPlayer.prepare()
        var cities = 0
        model.globe.onTrailStopPassed = { _ in
            cities += 1
            HapticPlayer.tick(0.55)
        }
        let duration = 7.0
        model.globe.growTrail(to: prologue.routeKm, duration: duration, followZoom: 1.25)
        try? await Task.sleep(for: .seconds(duration + 0.3))
        model.globe.onTrailStopPassed = nil
        HapticPlayer.conquest()
        withAnimation(Motion.bouncy) { isDone = true }
    }

    private func sinceText(_ date: Date?) -> LocalizedStringKey {
        guard let date else { return "Your steps so far" }
        return "Since \(date.formatted(.dateTime.year()))"
    }

    private func shareText(_ prologue: AppModel.Prologue) -> String {
        let place = prologue.place?.displayName() ?? ""
        return String(localized: "I've walked \(Format.km(prologue.km)) km — on foot I'd be in \(place). #Stepity")
    }
}

/// "That was before us. The new path starts today." The line resets to the home city, today's
/// steps since midnight walk the first stretch, and the first kilometre is conquered on the spot.
struct NewPathScreen: View {
    let model: AppModel
    @State private var stage = 0
    @State private var bursts: [ConfettiBurst] = []

    var body: some View {
        ZStack {
            GlobeView(controller: model.globe)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                if stage >= 1 {
                    Text("That was before us.")
                        .font(Typography.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .transition(.opacity)
                }
                if stage >= 2 {
                    Text("The new path starts today")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                Spacer()
                if stage >= 3, let snapshot = model.snapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        if snapshot.journey.distanceKm >= 1 {
                            Label("First kilometre — conquered", systemImage: "flag.checkered")
                                .font(Typography.title)
                                .foregroundStyle(.white)
                        }
                        Text("Today so far: \(Format.km(snapshot.journey.distanceKm)) km towards \(model.journey?.dream?.displayName() ?? "")")
                            .font(Typography.label)
                            .foregroundStyle(Palette.gold)
                        Button("Let's walk") { model.finishOnboarding() }
                            .buttonStyle(.capsule(.accent))
                    }
                    .padding(18)
                    .glassCard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)

            ConfettiView(bursts: bursts)
        }
        .task { await play() }
    }

    private func play() async {
        model.showJourneyOnGlobe(atKm: 0)
        model.globe.focusOnWalker(zoom: 9)
        withAnimation(Motion.smooth) { stage = 1 }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(Motion.bouncy) { stage = 2 }
        try? await Task.sleep(for: .seconds(1.2))
        let km = model.snapshot?.routeKm ?? 0
        model.globe.onTrailStopPassed = { _ in HapticPlayer.tick(0.6) }
        model.globe.growTrail(to: km, duration: 2.6, followZoom: 9)
        try? await Task.sleep(for: .seconds(2.8))
        model.globe.onTrailStopPassed = nil
        if km >= 1 {
            HapticPlayer.conquest()
            bursts.append(ConfettiBurst(origin: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.62), colors: [Palette.accent, Palette.gold, .white]))
            try? await Task.sleep(for: .seconds(0.4))
            HapticPlayer.stamp()
        }
        withAnimation(Motion.bouncy) { stage = 3 }
    }
}
