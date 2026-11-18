import simd

/// One point along the journey's trail, as the trail shader reads it. Mirrors `TrailPoint` in
/// GlobeShaders.metal.
struct TrailPoint: Sendable {
    /// xyz: on the unit globe. w: kilometres from the start of the journey.
    var position: SIMD4<Float>
    /// y: 1 at the first point, 2 at the last.
    var params: SIMD4<Float>
}

/// The whole journey as one ribbon: two vertices per point, made in the vertex shader (like
/// the rivers). The shader lights the part already walked and dims the rest.
struct TrailMesh: Sendable {
    var points: [TrailPoint] = []
    var indices: [UInt32] = []
}

/// A path on the globe with the distance walked to each point along it.
struct TrailPath: Sendable, Equatable {
    var coordinates: [GeoCoordinate]
    /// Kilometres from the start to each coordinate, rising.
    var kilometres: [Double]

    var totalKm: Double { kilometres.last ?? 0 }

    /// Where the walker is `km` along the path: between two coordinates, on the great circle
    /// joining them. Clamped to the path's ends.
    func coordinate(atKm km: Double) -> GeoCoordinate {
        guard let first = coordinates.first else { return GeoCoordinate(latitude: 0, longitude: 0) }
        guard km > 0, coordinates.count > 1 else { return first }
        guard km < totalKm else { return coordinates[coordinates.count - 1] }
        // The segment holding `km`: the last start at or before it.
        var low = 0, high = kilometres.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if kilometres[middle] <= km { low = middle } else { high = middle }
        }
        let span = kilometres[high] - kilometres[low]
        let t = span > 0 ? (km - kilometres[low]) / span : 0
        return TrailGeometry.slerp(coordinates[low], coordinates[high], t)
    }
}

/// Builds the trail's ribbon. Pure, covered by tests.
enum TrailGeometry {
    /// Earth's mean radius: kilometres per radian of arc.
    static let earthRadiusKm = 6371.0

    /// The ribbon along `path`, with points added every `stepKm` so it follows the globe's
    /// curve instead of cutting through it.
    static func mesh(_ path: TrailPath, stepKm: Double = 12) -> TrailMesh {
        var mesh = TrailMesh()
        guard path.coordinates.count >= 2 else { return mesh }
        var dense: [(GeoCoordinate, Double)] = [(path.coordinates[0], path.kilometres[0])]
        for i in 1..<path.coordinates.count {
            let a = path.coordinates[i - 1], b = path.coordinates[i]
            let startKm = path.kilometres[i - 1], endKm = path.kilometres[i]
            let pieces = max(1, Int(((endKm - startKm) / stepKm).rounded(.up)))
            for k in 1...pieces {
                let t = Double(k) / Double(pieces)
                dense.append((slerp(a, b, t), startKm + (endKm - startKm) * t))
            }
        }
        let last = dense.count - 1
        mesh.points.reserveCapacity(dense.count)
        for (k, point) in dense.enumerated() {
            let ends: Float = (k == 0 ? 1 : 0) + (k == last ? 2 : 0)
            mesh.points.append(TrailPoint(
                position: SIMD4(SIMD3<Float>(GeoMath.unitVector(point.0)), Float(point.1)),
                params: SIMD4(0, ends, 0, 0)
            ))
        }
        mesh.indices.reserveCapacity(last * 6)
        for k in 0..<UInt32(last) {
            let a = 2 * k, b = a + 2
            mesh.indices += [a, a + 1, b, a + 1, b + 1, b]
        }
        return mesh
    }

    /// The point `t` of the way from `a` to `b` along the great circle.
    static func slerp(_ a: GeoCoordinate, _ b: GeoCoordinate, _ t: Double) -> GeoCoordinate {
        let u = GeoMath.unitVector(a), v = GeoMath.unitVector(b)
        let angle = acos(max(-1, min(1, simd_dot(u, v))))
        guard angle > 1e-9 else { return a }
        let s = sin(angle)
        let p = u * (sin((1 - t) * angle) / s) + v * (sin(t * angle) / s)
        return GeoMath.coordinate(of: p)
    }

    /// Great-circle distance in kilometres.
    static func distanceKm(_ a: GeoCoordinate, _ b: GeoCoordinate) -> Double {
        GeoMath.angularDistance(a, b) * earthRadiusKm
    }
}

/// What the globe draws of the journey: the trail, how far along it the walker is, the
/// stops on the way.
struct TrailState {
    struct Stop: Equatable, Sendable {
        let coordinate: GeoCoordinate
        let km: Double
        /// A city rather than a village: drawn a little bigger.
        let isMajor: Bool
    }

    /// The line growing from one distance to another over a fixed time, eased at both ends:
    /// "since last time" plays the same few seconds whether it was 300 m or 30 km.
    struct Growth {
        let from: Double
        let to: Double
        let duration: Double
        var elapsed: Double = 0

        var isDone: Bool { elapsed >= duration }

        var value: Double {
            guard duration > 0 else { return to }
            let t = min(1, elapsed / duration)
            // Smootherstep: starts and stops gently, fast in the middle.
            let eased = t * t * t * (t * (6 * t - 15) + 10)
            return from + (to - from) * eased
        }
    }

    var path: TrailPath
    var stops: [Stop]
    var progressKm: Double = 0
    var growth: Growth?
    /// How brightly the walked part glows: 0 plain … 3 golden (the weekly streak).
    var glow: Float = 1
    /// The camera keeps the walker in view while the line grows, at this zoom.
    var followZoom: Double?
    /// Seconds since the trail appeared, for the walker's pulse.
    var clock: Double = 0
    /// Stops at or before this index have been reported as passed.
    var lastPassedStop = -1

    var walker: GeoCoordinate { path.coordinate(atKm: progressKm) }
    var isMoving: Bool { growth != nil }

    /// The index of the next stop ahead of the walker, if any.
    var nextStopIndex: Int? { stops.firstIndex { $0.km > progressKm + 1e-6 } }
}
