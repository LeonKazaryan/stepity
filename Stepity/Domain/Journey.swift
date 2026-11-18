import Foundation

/// A place on the way: a landmark at home, a town, a city, a rest stop between towns, or the
/// shore of a sea to cross.
struct JourneyStop: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Where the journey starts.
        case home
        /// A known spot in the home city: the first stops come within a day or two.
        case landmark
        /// A place from the city list.
        case town
        /// A city the route is planned through.
        case city
        /// Somewhere between towns, so the next stop is never more than a couple of days off.
        /// Named by its region; `area` is the town ahead.
        case restStop
        /// Getting on a ferry, or a boat across an ocean: the next stretch is water.
        case shore
        /// The end of the route.
        case dream
    }

    let id: Int
    let name: String
    let nameRu: String?
    /// Region or country, for rest stops and as a subtitle.
    let area: String?
    let areaRu: String?
    let countryCode: String
    let coordinate: GeoCoordinate
    /// Kilometres from home along the route.
    let km: Double
    let kind: Kind

    /// A city or more: big enough to name in "you'd be in …".
    var isMajor: Bool { kind == .city || kind == .dream || kind == .home }

    func displayName(language: String = PlaceNames.appLanguage) -> String {
        language.hasPrefix("ru") ? (nameRu ?? name) : name
    }

    func displayArea(language: String = PlaceNames.appLanguage) -> String? {
        language.hasPrefix("ru") ? (areaRu ?? area) : area
    }
}

/// The app's language, for place names.
enum PlaceNames {
    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }
}

/// The route from home to the dream, with every stop on it.
struct Journey: Sendable {
    let path: TrailPath
    let stops: [JourneyStop]
    /// The water crossings: kilometres where each starts and ends.
    let crossings: [ClosedRange<Double>]

    var totalKm: Double { path.totalKm }
    var dream: JourneyStop? { stops.last }

    /// The first stop ahead of `km`.
    func nextStop(after km: Double) -> JourneyStop? {
        stops.first { $0.km > km + 1e-6 }
    }

    /// The last stop at or before `km`.
    func lastStop(atOrBefore km: Double) -> JourneyStop? {
        stops.last { $0.km <= km + 1e-6 }
    }

    /// The last town or city reached: "you'd be in …".
    func lastPlace(atOrBefore km: Double) -> JourneyStop? {
        stops.last { $0.km <= km + 1e-6 && $0.kind != .restStop && $0.kind != .shore }
    }

    /// Stops passed going from `start` (exclusive) to `end` (inclusive).
    func stops(passedFrom start: Double, to end: Double) -> [JourneyStop] {
        stops.filter { $0.km > start + 1e-6 && $0.km <= end + 1e-6 }
    }

    /// Whether `km` is out on the water.
    func isOnWater(atKm km: Double) -> Bool {
        crossings.contains { $0.contains(km) && km > $0.lowerBound + 1e-6 }
    }

    /// Countries the walker has set foot in by `km`: they light up on the globe.
    func countries(upTo km: Double) -> Set<String> {
        Set(stops.filter { $0.km <= km + 1e-6 }.map(\.countryCode))
    }

    var trailStops: [TrailState.Stop] {
        stops.map { TrailState.Stop(coordinate: $0.coordinate, km: $0.km, isMajor: $0.isMajor) }
    }
}

/// A point the route is planned through.
struct Waypoint: Sendable {
    let name: String
    let nameRu: String
    let countryCode: String
    let coordinate: GeoCoordinate
    var kind: JourneyStop.Kind = .city
    /// The stretch after this point is water (a ferry, an ocean): no towns on it.
    var watersAfter = false

    init(_ name: String, _ nameRu: String, _ countryCode: String, _ latitude: Double, _ longitude: Double,
         kind: JourneyStop.Kind = .city, watersAfter: Bool = false) {
        self.name = name
        self.nameRu = nameRu
        self.countryCode = countryCode
        self.coordinate = GeoCoordinate(latitude: latitude, longitude: longitude)
        self.kind = kind
        self.watersAfter = watersAfter
    }
}

/// Plans routes: through the given waypoints, with towns from the city list near the line and
/// rest stops filling long gaps, so the next stop is never far.
enum JourneyPlanner {
    /// Towns this far either side of the line count as on the way.
    static let corridorKm = 9.0
    /// Towns smaller than this aren't stops: there are too many.
    static let minimumPopulation = 4_000

    /// The gap the rest stops keep: a few kilometres near home, growing to a long day's walk.
    static func restStopSpacing(atKm km: Double) -> Double {
        min(15, 4 + km / 50)
    }

    static func plan(_ waypoints: [Waypoint], cities: CityTable?) -> Journey {
        precondition(waypoints.count >= 2)
        // The route itself: straight (great-circle) between waypoints.
        var coordinates: [GeoCoordinate] = []
        var kilometres: [Double] = []
        var crossings: [ClosedRange<Double>] = []
        var km = 0.0
        for (i, point) in waypoints.enumerated() {
            if i > 0 {
                km += TrailGeometry.distanceKm(waypoints[i - 1].coordinate, point.coordinate)
                if waypoints[i - 1].watersAfter { crossings.append(kilometres[i - 1]...km) }
            }
            coordinates.append(point.coordinate)
            kilometres.append(km)
        }
        let path = TrailPath(coordinates: coordinates, kilometres: kilometres)

        // Waypoints become stops of their own kind.
        var stops: [Draft] = waypoints.enumerated().map { i, point in
            let kind: JourneyStop.Kind = i == 0 ? .home : i == waypoints.count - 1 ? .dream : point.watersAfter ? .shore : point.kind
            return Draft(name: point.name, nameRu: point.nameRu, area: nil, areaRu: nil, countryCode: point.countryCode,
                         coordinate: point.coordinate, km: kilometres[i], kind: kind, prominence: .infinity)
        }

        // Towns near each stretch over land.
        if let cities {
            stops += towns(near: waypoints, kilometres: kilometres, in: cities)
        }
        stops.sort { $0.km < $1.km }
        stops = thinned(stops)
        stops = withRestStops(stops, path: path, crossings: crossings, cities: cities)

        let final = stops.enumerated().map { index, draft in
            JourneyStop(id: index, name: draft.name, nameRu: draft.nameRu, area: draft.area, areaRu: draft.areaRu,
                        countryCode: draft.countryCode, coordinate: draft.coordinate, km: draft.km, kind: draft.kind)
        }
        return Journey(path: path, stops: final, crossings: crossings)
    }

    // MARK: - Steps

    private struct Draft {
        var name: String
        var nameRu: String?
        var area: String?
        var areaRu: String?
        var countryCode: String
        var coordinate: GeoCoordinate
        var km: Double
        var kind: JourneyStop.Kind
        /// Which of two close stops to keep.
        var prominence: Double
    }

    /// Towns within `corridorKm` of a land stretch, placed by how far along it they are.
    private static func towns(near waypoints: [Waypoint], kilometres: [Double], in table: CityTable) -> [Draft] {
        var found: [Draft] = []
        for i in 1..<waypoints.count where !waypoints[i - 1].watersAfter {
            let a = waypoints[i - 1].coordinate, b = waypoints[i].coordinate
            let ua = GeoMath.unitVector(a), ub = GeoMath.unitVector(b)
            let normal = simd_normalize(simd_cross(ua, ub))
            let length = acos(max(-1, min(1, simd_dot(ua, ub))))
            let margin = corridorKm / TrailGeometry.earthRadiusKm * 180 / .pi + 0.05
            let minLat = min(a.latitude, b.latitude) - margin, maxLat = max(a.latitude, b.latitude) + margin
            let lonMargin = margin / max(0.2, cos(GeoMath.radians((a.latitude + b.latitude) / 2)))
            let minLon = min(a.longitude, b.longitude) - lonMargin, maxLon = max(a.longitude, b.longitude) + lonMargin
            guard maxLon - minLon < 180 else { continue }

            for city in 0..<table.count {
                let lat = table.latitude(city), lon = table.longitude(city)
                guard lat >= minLat, lat <= maxLat, lon >= minLon, lon <= maxLon,
                      table.population(city) >= minimumPopulation else { continue }
                let p = GeoMath.unitVector(GeoCoordinate(latitude: lat, longitude: lon))
                let offLine = asin(max(-1, min(1, simd_dot(p, normal)))) * TrailGeometry.earthRadiusKm
                guard abs(offLine) <= corridorKm else { continue }
                // Its foot on the line, and how far along from `a`.
                let foot = simd_normalize(p - normal * simd_dot(p, normal))
                let fromA = acos(max(-1, min(1, simd_dot(ua, foot))))
                let toB = acos(max(-1, min(1, simd_dot(foot, ub))))
                guard abs(fromA + toB - length) < 1e-6, fromA * TrailGeometry.earthRadiusKm > 1.5,
                      toB * TrailGeometry.earthRadiusKm > 1.5 else { continue }
                let region = table.region(city)
                found.append(Draft(
                    name: table.name(city), nameRu: table.nameRu(city),
                    area: region?.name, areaRu: region?.nameRu,
                    countryCode: table.countryCode(city),
                    coordinate: GeoMath.coordinate(of: foot),
                    km: kilometres[i - 1] + fromA * TrailGeometry.earthRadiusKm,
                    kind: .town,
                    prominence: Double(table.population(city)) * (1 + Double(table.fame(city)) / 10)
                ))
            }
        }
        return found
    }

    /// Two stops closer than a couple of kilometres would blink past together: keep the more
    /// prominent. Waypoints always stay.
    private static func thinned(_ stops: [Draft]) -> [Draft] {
        var kept: [Draft] = []
        for stop in stops {
            if let last = kept.last, stop.km - last.km < max(2, restStopSpacing(atKm: stop.km) * 0.35) {
                if stop.prominence > last.prominence { kept[kept.count - 1] = stop }
                continue
            }
            kept.append(stop)
        }
        return kept
    }

    /// Rest stops in every gap longer than the spacing, named after the region they're in.
    /// Not on water: a crossing is one long stretch.
    private static func withRestStops(_ stops: [Draft], path: TrailPath, crossings: [ClosedRange<Double>], cities: CityTable?) -> [Draft] {
        guard var previous = stops.first else { return stops }
        var result = [previous]
        for stop in stops.dropFirst() {
            let gap = stop.km - previous.km
            let onWater = crossings.contains { $0.lowerBound <= previous.km + 1e-6 && $0.upperBound >= stop.km - 1e-6 }
            if !onWater {
                let spacing = restStopSpacing(atKm: previous.km)
                let count = Int((gap / spacing).rounded(.down))
                if count >= 1, gap > spacing * 1.3 {
                    let step = gap / Double(count + 1)
                    for k in 1...count {
                        let km = previous.km + step * Double(k)
                        let coordinate = path.coordinate(atKm: km)
                        let near = cities.flatMap { nearestArea(to: coordinate, in: $0) }
                        // Named by the region it's in; `area` holds the town it's heading for,
                        // shown as "→ Kordai · 23 km".
                        result.append(Draft(
                            name: near?.area ?? stop.name, nameRu: near?.areaRu ?? near?.area ?? stop.nameRu,
                            area: stop.name, areaRu: stop.nameRu,
                            countryCode: near?.countryCode ?? previous.countryCode,
                            coordinate: coordinate, km: km, kind: .restStop, prominence: 0
                        ))
                    }
                }
            }
            result.append(stop)
            previous = stop
        }
        return result
    }

    /// The region of the nearest town, for naming a rest stop: "Rest stop · Jambyl Region".
    private static func nearestArea(to coordinate: GeoCoordinate, in table: CityTable) -> (area: String?, areaRu: String?, countryCode: String)? {
        var best: (distance: Double, city: Int)?
        let box = 1.2
        for city in 0..<table.count {
            let lat = table.latitude(city), lon = table.longitude(city)
            guard abs(lat - coordinate.latitude) < box, abs(lon - coordinate.longitude) < box * 1.6 else { continue }
            let d = TrailGeometry.distanceKm(coordinate, GeoCoordinate(latitude: lat, longitude: lon))
            if d < (best?.distance ?? .infinity) { best = (d, city) }
        }
        guard let city = best?.city else { return nil }
        let region = table.region(city)
        return (region?.name, region?.nameRu, table.countryCode(city))
    }
}

import simd
