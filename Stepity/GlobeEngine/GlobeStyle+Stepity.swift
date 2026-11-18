extension GlobeStyle {
    /// Walked countries only warm up a little: the trail is what should glow.
    static let stepity = GlobeStyle(
        ocean: Palette.components(Palette.RGB.ocean),
        river: Palette.components(Palette.RGB.river),
        unclaimedLand: Palette.components(Palette.RGB.landUnclaimed),
        idleLand: Palette.idleLandShades,
        visitedLand: Palette.RGB.walked.enumerated().map { slot, warm in
            let idle = Palette.idleLandShades[slot % Palette.idleLandShades.count]
            return idle + (Palette.components(warm) - idle) * 0.28
        }
    )
}
