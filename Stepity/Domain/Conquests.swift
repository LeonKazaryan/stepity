import Foundation

/// Something to fill up and conquer: a height to climb by floors, a distance to walk.
/// Names are keys in the String Catalog.
struct Summit: Identifiable, Equatable, Sendable {
    enum Shape: Equatable, Sendable {
        /// A block of flats, a wheel, a tower, a skyscraper: drawn as buildings.
        case house, wheel, bayterek, eiffel, skyscraper
        /// A mountain with snow on top.
        case mountain
    }

    let id: String
    let name: LocalizedStringResource
    let metres: Double
    let shape: Shape

    var floors: Int { Int((metres / ActivityTotals.metresPerFloor).rounded()) }
}

/// The ladder of heights, climbed by floors from the day of install. The first steps are
/// easy on purpose: a house on day one, a wheel in a couple of days, then towers, then real
/// mountains months apart. Past Everest it keeps counting Everests.
enum HeightLadder {
    static let summits: [Summit] = [
        Summit(id: "house", name: "Five-storey block", metres: 15, shape: .house),
        Summit(id: "wheel", name: "Ferris wheel", metres: 60, shape: .wheel),
        Summit(id: "bayterek", name: "Bayterek", metres: 105, shape: .bayterek),
        Summit(id: "eiffel", name: "Eiffel Tower", metres: 330, shape: .eiffel),
        Summit(id: "burj", name: "Burj Khalifa", metres: 828, shape: .skyscraper),
        Summit(id: "fuji", name: "Mount Fuji", metres: 3_776, shape: .mountain),
        Summit(id: "montblanc", name: "Mont Blanc", metres: 4_806, shape: .mountain),
        Summit(id: "elbrus", name: "Elbrus", metres: 5_642, shape: .mountain),
        Summit(id: "khantengri", name: "Khan Tengri", metres: 7_010, shape: .mountain),
        Summit(id: "everest", name: "Everest", metres: 8_849, shape: .mountain),
    ]

    struct State: Equatable, Sendable {
        /// Conquered, in order.
        let conquered: [Summit]
        /// The one being climbed now.
        let current: Summit
        /// 0…1 of `current`.
        let fill: Double
        /// After Everest: how many times over.
        let everests: Int
    }

    /// Where `metres` climbed since the start stands on the ladder.
    static func state(metres: Double) -> State {
        let climbed = max(0, metres)
        let conquered = summits.filter { $0.metres <= climbed }
        if let current = summits.first(where: { $0.metres > climbed }) {
            return State(conquered: conquered, current: current, fill: climbed / current.metres, everests: 0)
        }
        // Everest again and again: the next one is always one Everest up.
        let everest = summits[summits.count - 1]
        let times = Int(climbed / everest.metres)
        return State(conquered: conquered, current: everest, fill: (climbed - Double(times) * everest.metres) / everest.metres, everests: times)
    }

    /// Summits conquered going from `start` to `end` metres.
    static func conquered(from start: Double, to end: Double) -> [Summit] {
        summits.filter { $0.metres > start && $0.metres <= end }
    }
}

/// Round distances worth a moment: the first kilometre, a marathon, the equator.
enum DistanceMilestones {
    struct Milestone: Identifiable, Equatable, Sendable {
        let id: String
        let name: LocalizedStringResource
        let km: Double
    }

    static let all: [Milestone] = [
        Milestone(id: "km1", name: "First kilometre", km: 1),
        Milestone(id: "km5", name: "5 km", km: 5),
        Milestone(id: "km10", name: "10 km", km: 10),
        Milestone(id: "half", name: "Half marathon", km: 21.0975),
        Milestone(id: "marathon", name: "Marathon", km: 42.195),
        Milestone(id: "km100", name: "100 km", km: 100),
        Milestone(id: "km250", name: "250 km", km: 250),
        Milestone(id: "km500", name: "500 km", km: 500),
        Milestone(id: "km1000", name: "1,000 km", km: 1_000),
        Milestone(id: "km2500", name: "2,500 km", km: 2_500),
        Milestone(id: "km5000", name: "5,000 km", km: 5_000),
        Milestone(id: "km10000", name: "10,000 km", km: 10_000),
        Milestone(id: "equator", name: "Around the equator", km: 40_075),
    ]

    static func crossed(from start: Double, to end: Double) -> [Milestone] {
        all.filter { $0.km > start && $0.km <= end }
    }

    static func next(after km: Double) -> Milestone? {
        all.first { $0.km > km }
    }
}

/// This week's goal: one thing to walk the length of, a little more than a usual week.
/// With friends it's also the race's route (later).
struct WeeklyGoal: Equatable, Sendable {
    struct Course: Identifiable, Equatable, Sendable {
        let id: String
        let name: LocalizedStringResource
        let km: Double
        let symbol: String
    }

    /// A stadium lap is 400 m exactly; the named courses are rounded and approximate: check
    /// them before release. Laps fill the gaps, so a goal is never far above a usual week.
    static let courses: [Course] = [
        Course(id: "stadium30", name: "30 laps of a stadium", km: 12, symbol: "circle.dashed"),
        Course(id: "stadium40", name: "40 laps of a stadium", km: 16, symbol: "circle.dashed"),
        Course(id: "stadium50", name: "50 laps of a stadium", km: 20, symbol: "circle.dashed"),
        Course(id: "manhattan", name: "Manhattan end to end", km: 21.6, symbol: "building.2"),
        Course(id: "stadium60", name: "60 laps of a stadium", km: 24, symbol: "circle.dashed"),
        Course(id: "stadium70", name: "70 laps of a stadium", km: 28, symbol: "circle.dashed"),
        Course(id: "bosphorus", name: "Along the Bosphorus", km: 31, symbol: "water.waves"),
        Course(id: "stadium85", name: "85 laps of a stadium", km: 34, symbol: "circle.dashed"),
        Course(id: "stadium90", name: "90 laps of a stadium", km: 36, symbol: "circle.dashed"),
        Course(id: "stadium100", name: "100 laps of a stadium", km: 40, symbol: "circle.dashed"),
        Course(id: "marathon", name: "A marathon", km: 42.2, symbol: "figure.run"),
        Course(id: "manhattan2", name: "Manhattan there and back", km: 43.2, symbol: "building.2"),
        Course(id: "stadium120", name: "120 laps of a stadium", km: 48, symbol: "circle.dashed"),
        Course(id: "seine", name: "The Seine through Paris ×4", km: 52, symbol: "water.waves"),
        Course(id: "stadium150", name: "150 laps of a stadium", km: 60, symbol: "circle.dashed"),
        Course(id: "goldengate", name: "Golden Gate Bridge ×25", km: 68, symbol: "road.lanes"),
    ]

    let course: Course

    /// The course a little longer than a usual week: about 10% more than the average of the
    /// last weeks, at least a short one for a first week without history.
    static func pick(usualWeekKm: Double?) -> WeeklyGoal {
        let target = max(10, (usualWeekKm ?? 15) * 1.1)
        let course = courses.first { $0.km >= target } ?? courses[courses.count - 1]
        return WeeklyGoal(course: course)
    }

    func fill(km: Double) -> Double { min(1, max(0, km / course.km)) }
}

/// Food and other things the day's energy turns into. Kilocalories per piece are rough.
enum EnergyThings {
    struct Thing: Identifiable, Equatable, Sendable {
        let id: String
        let name: LocalizedStringResource
        let kcal: Double
    }

    static let chip = Thing(id: "chip", name: "chips", kcal: 10.5)
    static let fry = Thing(id: "fry", name: "fries", kcal: 3.4)
    static let baursak = Thing(id: "baursak", name: "baursaks", kcal: 60)
    static let burger = Thing(id: "burger", name: "burgers", kcal: 550)
    static let food: [Thing] = [chip, fry, baursak, burger]

    /// An iPhone's battery holds about 14 Wh; a kilocalorie is 1.163 Wh.
    static func phoneCharges(kcal: Double) -> Double { kcal * 1.163 / 14 }

    static func count(of thing: Thing, kcal: Double) -> Int { Int((kcal / thing.kcal).rounded()) }
}

/// Today's distance as something familiar.
enum DistanceThings {
    struct Thing: Equatable, Sendable {
        let name: LocalizedStringResource
        let km: Double
        let symbol: String
    }

    static let stadiumLap = Thing(name: "stadium laps", km: 0.4, symbol: "circle.dashed")
    static let footballPitch = Thing(name: "football pitches", km: 0.105, symbol: "sportscourt")
    static let goldenGate = Thing(name: "Golden Gate Bridges", km: 2.737, symbol: "road.lanes")

    /// Pick what reads best for `km`: pitches for a short walk, laps for a normal day, bridges
    /// for a long one.
    static func best(for km: Double) -> (thing: Thing, count: Double) {
        let thing = km < 1 ? footballPitch : km < 9 ? stadiumLap : goldenGate
        return (thing, km / thing.km)
    }
}
