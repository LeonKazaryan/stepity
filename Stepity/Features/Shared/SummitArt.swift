import SwiftUI

/// A summit's silhouette, drawn in code like everything else: a block of flats, a wheel,
/// Bayterek, the Eiffel Tower, a skyscraper, a mountain. Filled from the bottom like a glass.
struct SummitSilhouette: Shape {
    let shape: Summit.Shape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .house: house(rect)
        case .wheel: wheel(rect)
        case .bayterek: bayterek(rect)
        case .eiffel: eiffel(rect)
        case .skyscraper: skyscraper(rect)
        case .mountain: mountain(rect)
        }
    }

    private func house(_ r: CGRect) -> Path {
        var p = Path()
        let body = CGRect(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.3, width: r.width * 0.64, height: r.height * 0.7)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
        p.move(to: CGPoint(x: body.minX - r.width * 0.06, y: body.minY + 2))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.08))
        p.addLine(to: CGPoint(x: body.maxX + r.width * 0.06, y: body.minY + 2))
        p.closeSubpath()
        return p
    }

    private func wheel(_ r: CGRect) -> Path {
        var p = Path()
        let d = min(r.width, r.height * 0.86)
        let circle = CGRect(x: r.midX - d / 2, y: r.minY, width: d, height: d)
        p.addEllipse(in: circle)
        // The legs.
        p.move(to: CGPoint(x: r.midX - d * 0.36, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - d * 0.06, y: circle.midY))
        p.addLine(to: CGPoint(x: r.midX + d * 0.06, y: circle.midY))
        p.addLine(to: CGPoint(x: r.midX + d * 0.36, y: r.maxY))
        p.closeSubpath()
        return p
    }

    private func bayterek(_ r: CGRect) -> Path {
        var p = Path()
        let ball = r.width * 0.34
        let top = r.minY
        let ballRect = CGRect(x: r.midX - ball / 2, y: top + r.height * 0.06, width: ball, height: ball)
        p.addEllipse(in: ballRect)
        // The crown holding the golden ball.
        p.move(to: CGPoint(x: r.midX - ball * 0.75, y: top))
        p.addQuadCurve(to: CGPoint(x: r.midX - r.width * 0.05, y: ballRect.maxY + r.height * 0.1), control: CGPoint(x: r.midX - ball * 0.75, y: ballRect.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.05, y: ballRect.maxY + r.height * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.midX + ball * 0.75, y: top), control: CGPoint(x: r.midX + ball * 0.75, y: ballRect.maxY))
        p.addLine(to: CGPoint(x: r.midX + ball * 0.52, y: top + r.height * 0.02))
        p.addQuadCurve(to: CGPoint(x: r.midX - ball * 0.52, y: top + r.height * 0.02), control: CGPoint(x: r.midX, y: ballRect.maxY + r.height * 0.04))
        p.closeSubpath()
        // The white stem, flaring at the foot.
        p.move(to: CGPoint(x: r.midX - r.width * 0.05, y: ballRect.maxY + r.height * 0.08))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.07, y: r.maxY - r.height * 0.12))
        p.addQuadCurve(to: CGPoint(x: r.midX - r.width * 0.24, y: r.maxY), control: CGPoint(x: r.midX - r.width * 0.08, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.24, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX + r.width * 0.07, y: r.maxY - r.height * 0.12), control: CGPoint(x: r.midX + r.width * 0.08, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.05, y: ballRect.maxY + r.height * 0.08))
        p.closeSubpath()
        return p
    }

    private func eiffel(_ r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + w * 0.035, y: r.minY + h * 0.2))
        p.addQuadCurve(to: CGPoint(x: r.midX + w * 0.4, y: r.maxY), control: CGPoint(x: r.midX + w * 0.1, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.midX + w * 0.22, y: r.maxY))
        // The arch between the legs.
        p.addQuadCurve(to: CGPoint(x: r.midX - w * 0.22, y: r.maxY), control: CGPoint(x: r.midX, y: r.maxY - h * 0.28))
        p.addLine(to: CGPoint(x: r.midX - w * 0.4, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX - w * 0.035, y: r.minY + h * 0.2), control: CGPoint(x: r.midX - w * 0.1, y: r.minY + h * 0.75))
        p.closeSubpath()
        // The two platforms.
        p.addRect(CGRect(x: r.midX - w * 0.13, y: r.minY + h * 0.52, width: w * 0.26, height: h * 0.025))
        p.addRect(CGRect(x: r.midX - w * 0.24, y: r.minY + h * 0.74, width: w * 0.48, height: h * 0.03))
        return p
    }

    private func skyscraper(_ r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        // Setbacks narrowing to a spire, like the Burj.
        let tiers: [(width: CGFloat, top: CGFloat)] = [(0.5, 0.62), (0.38, 0.42), (0.26, 0.24), (0.14, 0.1)]
        for tier in tiers {
            p.addRect(CGRect(x: r.midX - w * tier.width / 2, y: r.minY + h * tier.top, width: w * tier.width, height: h * (1 - tier.top)))
        }
        p.move(to: CGPoint(x: r.midX - w * 0.02, y: r.minY + h * 0.1))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + w * 0.02, y: r.minY + h * 0.1))
        p.closeSubpath()
        return p
    }

    private func mountain(_ r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.52))
        p.addLine(to: CGPoint(x: r.minX + w * 0.32, y: r.minY + h * 0.6))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.64, y: r.minY + h * 0.26))
        p.addLine(to: CGPoint(x: r.minX + w * 0.72, y: r.minY + h * 0.2))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A summit filling up: the silhouette, liquid sunrise rising inside it with a moving wave,
/// a snow cap on mountains. `fill` animates; the wave keeps moving while it does.
struct SummitFill: View {
    let summit: Summit
    let fill: Double
    var showsPercent = true

    @State private var shown = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                SummitSilhouette(shape: summit.shape)
                    .fill(Palette.ice.opacity(0.14))
                SummitSilhouette(shape: summit.shape)
                    .stroke(Palette.ice.opacity(0.35), lineWidth: 1.2)
                LiquidFill(level: shown, phase: time * 2.2, amplitude: shown > 0.001 && shown < 0.999 ? 4 : 0)
                    .fill(Palette.sunriseGradient)
                    .mask(SummitSilhouette(shape: summit.shape))
                    .shadow(color: Palette.accent.opacity(0.6), radius: 12)
                if summit.shape == .mountain {
                    SnowCap()
                        .fill(.white.opacity(0.9))
                        .mask(SummitSilhouette(shape: summit.shape))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showsPercent {
                Text(shown, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .contentTransition(.numericText(value: shown))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(.bottom, 8)
            }
        }
        .onAppear { animate(to: fill) }
        .onChange(of: fill) { _, value in animate(to: value) }
        .accessibilityElement()
        .accessibilityLabel(Text(summit.name))
        .accessibilityValue(Text(fill, format: .percent.precision(.fractionLength(0))))
    }

    private func animate(to value: Double) {
        if reduceMotion {
            shown = value
        } else {
            withAnimation(.spring(duration: 1.6, bounce: 0.12)) { shown = value }
        }
    }
}

/// Liquid up to `level` (0…1 of the height), its surface a moving wave.
struct LiquidFill: Shape {
    var level: Double
    var phase: Double
    var amplitude: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.maxY - rect.height * min(1, max(0, level))
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 24
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let wave = sin(Double(i) / Double(steps) * .pi * 2.5 + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y + wave))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Snow on the top fifth of a mountain, with a ragged edge.
private struct SnowCap: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let line = rect.minY + rect.height * 0.2
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: line))
        let teeth = 7
        for i in (0...teeth).reversed() {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(teeth)
            p.addLine(to: CGPoint(x: x, y: line + (i.isMultiple(of: 2) ? 4 : -3)))
        }
        p.closeSubpath()
        return p
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(HeightLadder.summits.prefix(6)) { summit in
            SummitFill(summit: summit, fill: 0.62)
                .frame(width: 70, height: 110)
        }
    }
    .padding()
    .background(SpaceBackground())
}
