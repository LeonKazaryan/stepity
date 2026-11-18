import SwiftUI

/// Brand colors. Values mirror docs/02-design.md.
///
/// Stepity is a night sky with a sunrise on the horizon: deep indigo everywhere, and one warm
/// color for everything you did. The trail, the fills and the numbers that grow are all
/// sunrise; the world you haven't walked yet stays cool and quiet.
enum Palette {
    static let night = Color(rgb: 0x0A0C24)
    static let nebula = Color(rgb: 0x2B1F63)
    /// The one warm color: progress, the trail, primary buttons.
    static let accent = Color(rgb: RGB.sunrise)
    static let accentLight = Color(rgb: 0xFFB36B)
    /// The second warm stop of every progress gradient.
    static let ember = Color(rgb: RGB.ember)
    /// The trail's bright core and the glow around things just conquered.
    static let gold = Color(rgb: RGB.gold)
    static let atmosphere = Color(rgb: 0x7DD3FC)
    /// Snow, water, the part of a mountain not yet climbed.
    static let ice = Color(rgb: 0x9FD8FF)
    static let mint = Color(rgb: 0x4BE8A5)
    /// The capital star on city names.
    static let capital = Color(rgb: RGB.gold)

    /// Progress drawn as a gradient: bars, fills, rings.
    static let sunriseGradient = LinearGradient(
        colors: [Color(rgb: RGB.ember), Color(rgb: RGB.sunrise), Color(rgb: RGB.gold)],
        startPoint: .bottom, endPoint: .top
    )

    /// Countries the trail has crossed, in slot order; neighbours never share one.
    static let candy: [Color] = RGB.walked.map(Color.init(rgb:))

    /// Raw values for places that can't take a `Color`, like the Metal globe.
    enum RGB {
        static let sunrise: UInt32 = 0xFF8A3D
        static let ember: UInt32 = 0xFF4F6D
        static let gold: UInt32 = 0xFFD45E
        static let ocean: UInt32 = 0x172E73
        /// A touch lighter than the ocean, so a thin line still reads on dark land.
        static let river: UInt32 = 0x23469A
        static let landIdle: UInt32 = 0x3D4068
        static let landUnclaimed: UInt32 = 0x33365A
        /// Countries the trail has crossed: warm, distinct from each other, readable on the ocean.
        static let walked: [UInt32] = [0xFF8A3D, 0xFF6A88, 0xFFC24D, 0xF9844A, 0xFF9E7A, 0xE8738F]
        static let candy: [UInt32] = walked
    }

    /// sRGB components in 0…1.
    static func components(_ rgb: UInt32) -> SIMD3<Float> {
        SIMD3(Float((rgb >> 16) & 0xFF), Float((rgb >> 8) & 0xFF), Float(rgb & 0xFF)) / 255
    }

    /// Unwalked land in six close shades, one per color slot. Neighbours never share a
    /// slot, so borders read without drawing lines.
    static let idleLandShades: [SIMD3<Float>] = [0.86, 1.12, 0.95, 1.2, 0.9, 1.04].map {
        components(RGB.landIdle) * Float($0)
    }
}

extension Color {
    init(rgb: UInt32) {
        let c = Palette.components(rgb)
        self.init(red: Double(c.x), green: Double(c.y), blue: Double(c.z))
    }
}
