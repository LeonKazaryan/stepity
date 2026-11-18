import QuartzCore
import simd

/// The journey on the globe: the trail, the walker on it and the stops along the way.
extension GlobeController {
    /// Shows `path` with the walker `progressKm` along it. Replaces any trail shown before.
    func setTrail(_ path: TrailPath, stops: [TrailState.Stop], progressKm: Double) {
        let mesh = TrailGeometry.mesh(path)
        do {
            try trailRenderer?.setTrail(mesh)
        } catch {
            trail = nil
            return
        }
        var state = TrailState(path: path, stops: stops)
        state.progressKm = min(max(0, progressKm), path.totalKm)
        state.lastPassedStop = (stops.lastIndex { $0.km <= state.progressKm }) ?? -1
        trail = state
        requestFrame()
    }

    /// Removes the trail.
    func clearTrail() {
        try? trailRenderer?.setTrail(TrailMesh())
        trail = nil
        requestFrame()
    }

    /// Jumps the walker to `km` without animating.
    func setTrailProgress(_ km: Double) {
        guard var state = trail else { return }
        state.growth = nil
        state.followZoom = nil
        state.progressKm = min(max(0, km), state.path.totalKm)
        state.lastPassedStop = (state.stops.lastIndex { $0.km <= state.progressKm }) ?? -1
        trail = state
        requestFrame()
    }

    /// Grows the line to `km` over `duration` seconds. With `followZoom` the camera rides
    /// along, keeping the walker in the middle at that zoom. Every stop it passes is reported
    /// through `onTrailStopPassed`. Reduce Motion jumps straight there.
    func growTrail(to km: Double, duration: Double, followZoom: Double? = nil) {
        guard var state = trail else { return }
        let target = min(max(0, km), state.path.totalKm)
        if reduceMotion || duration <= 0 {
            state.growth = nil
            state.progressKm = target
            trail = state
            reportPassedStops()
            if let followZoom { fly(toCoordinate: state.walker, zoom: followZoom) }
            requestFrame()
            return
        }
        state.growth = TrailState.Growth(from: state.progressKm, to: target, duration: duration)
        state.followZoom = followZoom
        trail = state
        requestFrame()
    }

    /// How brightly the walked part glows: 0 plain … 3 golden.
    func setTrailGlow(_ glow: Float) {
        trail?.glow = glow
        requestFrame()
    }

    /// Turns the globe to the walker at `zoom`.
    func focusOnWalker(zoom: Double) {
        guard let walker = trail?.walker else { return }
        fly(toCoordinate: walker, zoom: zoom)
    }

    /// Where the walker shows on screen, if it's on the near side.
    var walkerScreenPoint: CGPoint? {
        guard let walker = trail?.walker else { return nil }
        return screenPoint(of: walker)?.point
    }

    // MARK: - Frame

    /// Advances the growing line and the walker's pulse, and hands the renderer this frame's
    /// look. Runs every frame from `tick`.
    func stepTrail(_ dt: Double) {
        guard var state = trail, let renderer = trailRenderer else { return }
        state.clock += dt
        if var growth = state.growth {
            growth.elapsed += dt
            state.progressKm = growth.value
            state.growth = growth.isDone ? nil : growth
            if growth.isDone { state.followZoom = nil }
            if let zoom = state.followZoom {
                aim(at: state.walker, zoom: zoom)
            }
        }
        trail = state
        reportPassedStops()

        // Kilometres per point at this zoom: the shader keeps dots and the head's spark the
        // same size on screen.
        let kmPerPoint = TrailGeometry.earthRadiusKm / max(camera.pointsPerRadian, 1)
        let halfWidth = Float(7 + 2.5 * Double(state.glow))
        var uniforms = renderer.trailUniforms
        uniforms.style = SIMD4(Float(state.progressKm), halfWidth, Float(kmPerPoint), state.glow)
        uniforms.shape = SIMD4(Self.trailRadius, Float(state.clock), Float(state.path.totalKm), 0)
        uniforms.head = SIMD4(Palette.components(Palette.RGB.gold), 1)
        uniforms.body = SIMD4(Palette.components(Palette.RGB.sunrise), 1)
        uniforms.tail = SIMD4(Palette.components(Palette.RGB.ember), 1)
        uniforms.ahead = SIMD4(1, 1, 1, 0.3)
        renderer.trailUniforms = uniforms
    }

    /// The walker and the stops, as markers drawn with the cities'.
    func trailMarkers() -> [GlobeRenderer.Marker] {
        guard let state = trail else { return [] }
        var markers: [GlobeRenderer.Marker] = []
        let lift = Self.trailRadius * 1.0004
        let next = state.nextStopIndex
        // Stops show once the globe is close enough to tell them apart; the next one always.
        let closeness = min(1, max(0, (displayedZoom - 1.6) / 2.4))
        let gold = Palette.components(Palette.RGB.gold)
        let pulse = Float(state.clock.truncatingRemainder(dividingBy: 1.6) / 1.6)

        for (index, stop) in state.stops.enumerated() {
            let isNext = index == next
            let alpha = isNext ? 1 : Float(closeness) * (stop.isMajor ? 1 : 0.8)
            guard alpha > 0.02 else { continue }
            let passed = stop.km <= state.progressKm
            let radius: Float = isNext ? 4.2 : stop.isMajor ? 3.4 : 2.6
            markers.append(GlobeRenderer.Marker(
                position: SIMD4(SIMD3<Float>(GeoMath.unitVector(stop.coordinate)) * lift, radius),
                color: SIMD4(gold, alpha),
                params: SIMD4(1, isNext ? pulse : -1, isNext ? 2 : passed ? 1 : 0, 4)
            ))
        }

        markers.append(GlobeRenderer.Marker(
            position: SIMD4(SIMD3<Float>(GeoMath.unitVector(state.walker)) * lift, 5.5),
            color: SIMD4(gold, 1),
            params: SIMD4(1, Float(state.clock.truncatingRemainder(dividingBy: 2.2) / 2.2), 0, 3)
        ))
        return markers
    }

    /// Reports every stop the walker reached since the last report.
    private func reportPassedStops() {
        guard var state = trail else { return }
        let reached = (state.stops.lastIndex { $0.km <= state.progressKm }) ?? -1
        guard reached > state.lastPassedStop else {
            // Going back (a reset): forget the stops behind.
            if reached < state.lastPassedStop {
                state.lastPassedStop = reached
                trail = state
            }
            return
        }
        let passed = (state.lastPassedStop + 1)...reached
        state.lastPassedStop = reached
        trail = state
        for index in passed { onTrailStopPassed?(index) }
    }

    /// Just above walked countries, which rise a little: the line never sinks into the land.
    static let trailRadius = GlobeTuning.landRadius * Float(1 + GlobeTuning.visitedLift) * 1.0012
}
