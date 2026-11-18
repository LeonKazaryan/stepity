import SwiftUI

/// Today, translated: the steps, and what they mean — a familiar distance, food falling into
/// a bowl for the energy, a piece of a tower for the floors. No charts, no goals.
struct TodayScreen: View {
    let model: AppModel
    @State private var food = EnergyThings.chip

    var body: some View {
        ScrollView {
            if let snapshot = model.snapshot {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Eyebrow(text: "Today")
                        HeroNumber(value: snapshot.today.steps, caption: "steps")
                    }
                    .padding(.top, 12)

                    distanceCard(km: snapshot.today.distanceKm)
                    energyCard(kcal: snapshot.today.activeKcal)
                    floorsCard(snapshot: snapshot)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func distanceCard(km: Double) -> some View {
        let best = DistanceThings.best(for: km)
        return HStack(spacing: 16) {
            Image(systemName: best.thing.symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.sunriseGradient)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Distance")
                Text("\(Format.km(km)) km")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                distanceLabel(best.thing, Int(best.count.rounded()))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard()
    }

    private func energyCard(kcal: Double) -> some View {
        let showsFood = model.store.showsFood
        let count = EnergyThings.count(of: food, kcal: kcal)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Energy")
                    Text("≈ \(Int(kcal.rounded())) kcal")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    model.store.showsFood.toggle()
                } label: {
                    Image(systemName: showsFood ? "fork.knife" : "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(showsFood ? Text("Show as phone charges") : Text("Show as food"))
            }

            if showsFood {
                foodLabel(food, count)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.gold)
                    .contentTransition(.numericText(value: Double(count)))
                FoodDropView(thing: food, count: count)
                    .frame(height: 210)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                HStack(spacing: 8) {
                    ForEach(EnergyThings.food) { thing in
                        Button {
                            withAnimation(Motion.snappy) { food = thing }
                        } label: {
                            Text(thing.name)
                                .font(Typography.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(thing == food ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.white.opacity(0.1)), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .sensoryFeedback(Haptics.select, trigger: food)
            } else {
                let charges = EnergyThings.phoneCharges(kcal: kcal)
                HStack(spacing: 12) {
                    Image(systemName: "battery.100percent.bolt")
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.mint)
                    Text("Enough to charge an iPhone \(max(1, Int(charges.rounded()))) times")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
            }
            Text("An estimate: without an Apple Watch it's worked out from your steps.")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(18)
        .glassCard()
    }

    private func foodLabel(_ thing: EnergyThings.Thing, _ count: Int) -> Text {
        switch thing.id {
        case EnergyThings.chip.id: Text("≈ \(count) chips")
        case EnergyThings.fry.id: Text("≈ \(count) fries")
        case EnergyThings.baursak.id: Text("≈ \(count) baursaks")
        default: Text("≈ \(count) burgers")
        }
    }

    private func distanceLabel(_ thing: DistanceThings.Thing, _ count: Int) -> Text {
        switch thing.km {
        case DistanceThings.footballPitch.km: Text("≈ \(max(1, count)) football pitches")
        case DistanceThings.stadiumLap.km: Text("≈ \(max(1, count)) stadium laps")
        default: Text("≈ \(max(1, count)) Golden Gate Bridges")
        }
    }

    private func floorsCard(snapshot: ProgressSnapshot) -> some View {
        let ladder = snapshot.ladder
        let metres = snapshot.today.metresClimbed
        return HStack(spacing: 16) {
            SummitFill(summit: ladder.current, fill: ladder.fill, showsPercent: false)
                .frame(width: 64, height: 86)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Floors")
                Text("Floors: \(snapshot.today.floors) · \(Int(metres)) m")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                Text("+\(Int(metres)) m towards \(Text(ladder.current.name))")
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard()
    }
}
